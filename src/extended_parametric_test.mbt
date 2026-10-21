///|
test "parametric compact counting configurations support deletion" {
  let configurations : Array[(Int32, Int32)] = [
    (16, 1),
    (64, 2),
    (128, 3),
    (1024, 5),
  ]
  for configuration in configurations {
    let (slot_count, hash_count) = configuration
    let filter = @src.CompactCountingBloomFilter::with_size(
      slot_count, hash_count,
    )
    let keys = ["a", "b", "c", "d", "e", "f", "g", "h"]
    filter.insert_all(keys)
    assert_true(filter.contains_all(keys))
    for key in keys {
      assert_true(filter.remove(key))
    }
    assert_true(filter.is_empty())
    for key in keys {
      assert_false(filter.contains(key))
    }
  }
}

///|
test "parametric compact counting false positive rate stays near target" {
  let filter = @src.CompactCountingBloomFilter::new(1000, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("present-" + i.to_string())
  }
  let mut false_positives = 0
  for i = 0; i < 5000; i = i + 1 {
    if filter.contains("absent-" + i.to_string()) {
      false_positives = false_positives + 1
    }
  }
  assert_true(false_positives.to_double() / 5000.0 < 0.03)
}

///|
test "randomized compact counting operations match a live-key model" {
  let key_space = 64
  for round = 1; round <= 50; round = round + 1 {
    let filter = @src.CompactCountingBloomFilter::with_size(512, 4)
    let live : Array[Int32] = Array::make(key_space, 0)
    let mut seed = round
    for step = 0; step < 600; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_space
      let action = seed / 31 % 4
      if action == 0 {
        filter.insert(key)
        live[key] = live[key] + 1
      } else if action == 1 {
        if live[key] > 0 {
          assert_true(filter.remove(key))
          live[key] = live[key] - 1
        }
      } else if action == 2 {
        if live[key] > 0 {
          assert_true(filter.contains(key))
          assert_true(filter.count_of(key) >= live[key].min(15))
        }
      } else {
        let copy = filter.copy()
        let restored = @src.CompactCountingBloomFilter::from_bytes(
          filter.to_bytes(),
        )
        for k = 0; k < key_space; k = k + 1 {
          if live[k] > 0 {
            assert_true(restored.contains(k))
            assert_true(copy.contains(k))
          }
          assert_eq(restored.count_of(k), filter.count_of(k))
        }
        assert_eq(restored.count(), filter.count())
      }
    }
    let mut total = 0
    for key = 0; key < key_space; key = key + 1 {
      total = total + live[key]
      if live[key] > 0 {
        assert_true(filter.contains(key))
      }
    }
    assert_eq(filter.count(), total)
  }
}

///|
test "parametric scalable bloom growth preserves every key" {
  let configurations : Array[(Int32, Double)] = [
    (1, 0.5),
    (4, 0.01),
    (100, 0.005),
  ]
  for configuration in configurations {
    let (initial_capacity, target_rate) = configuration
    let filter = @src.ScalableBloomFilter::new(initial_capacity, target_rate)
    let total = initial_capacity * 3
    for i = 0; i < total; i = i + 1 {
      filter.insert("key-" + i.to_string())
    }
    assert_eq(filter.count(), total)
    assert_true(filter.slice_count() >= 1)
    assert_true(filter.capacity() >= total.to_int64())
    for i = 0; i < total; i = i + 1 {
      assert_true(filter.contains("key-" + i.to_string()))
    }
  }
}

///|
test "parametric scalable bloom unions keep every key and round trip" {
  let configurations : Array[(Int32, Double)] = [
    (1, 0.05),
    (4, 0.01),
    (16, 0.001),
  ]
  for configuration in configurations {
    let (initial_capacity, target_rate) = configuration
    let left = @src.ScalableBloomFilter::new(initial_capacity, target_rate)
    let right = @src.ScalableBloomFilter::new(initial_capacity, target_rate)
    let per_side = initial_capacity * 2
    for i = 0; i < per_side; i = i + 1 {
      left.insert("left-" + i.to_string())
      right.insert("right-" + i.to_string())
    }
    let combined = left.union(right)
    assert_eq(combined.count(), left.count() + right.count())
    for i = 0; i < per_side; i = i + 1 {
      assert_true(combined.contains("left-" + i.to_string()))
      assert_true(combined.contains("right-" + i.to_string()))
    }
    assert_true(left.is_subset_of(combined))
    assert_true(right.is_subset_of(combined))
    let restored = @src.ScalableBloomFilter::from_bytes(combined.to_bytes())
    assert_eq(restored.count(), combined.count())
    assert_eq(restored.slice_count(), combined.slice_count())
    for i = 0; i < per_side; i = i + 1 {
      assert_true(restored.contains("left-" + i.to_string()))
      assert_true(restored.contains("right-" + i.to_string()))
    }
  }
}
