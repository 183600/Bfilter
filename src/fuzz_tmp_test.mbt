///|
test "fuzz scalable counting set operations" {
  let key_count = 18
  for round = 1; round <= 200; round = round + 1 {
    let capacity = round % 5 + 1
    let rate = 0.03
    let left = @src.ScalableCountingBloomFilter::new(capacity, rate)
    let right = @src.ScalableCountingBloomFilter::new(capacity, rate)
    let live_left : Array[Int32] = Array::make(key_count, 0)
    let live_right : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 7919 + 13
    for step = 0; step < 160; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let action = seed / 31 % 6
      if action == 0 {
        left.insert(key)
        live_left[key] = live_left[key] + 1
      } else if action == 1 {
        right.insert(key)
        live_right[key] = live_right[key] + 1
      } else if action == 2 && live_left[key] > 0 {
        assert_true(left.remove(key))
        live_left[key] = live_left[key] - 1
      } else if action == 3 && live_right[key] > 0 {
        assert_true(right.remove(key))
        live_right[key] = live_right[key] - 1
      } else if action == 4 {
        assert_eq(left.count_of(key), live_left[key])
        assert_eq(right.count_of(key), live_right[key])
      } else {
        let la = left.insert_if_absent(key)
        if live_left[key] == 0 && la {
          live_left[key] = 1
        }
      }
    }
    let combined = left.union(right)
    let common = left.intersection(right)
    for key = 0; key < key_count; key = key + 1 {
      let a = live_left[key]
      let b = live_right[key]
      if a > 0 || b > 0 {
        assert_true(combined.contains(key))
        let c = combined.count_of(key)
        if a > 0 && b > 0 {
          assert_true(c >= a.max(b))
        } else if a > 0 {
          assert_eq(c, a)
        } else {
          assert_eq(c, b)
        }
      }
      if a > 0 && b > 0 {
        assert_true(common.contains(key))
        assert_true(common.count_of(key) >= a.min(b))
        assert_true(common.count_of(key) <= common.count() - (common.count() - common.count_of(key)))
      } else {
        assert_eq(common.count_of(key), 0)
      }
    }
    assert_true(left.is_subset_of(combined))
    assert_true(right.is_subset_of(combined))
    assert_true(common.is_subset_of(left))
    assert_true(common.is_subset_of(right))
    let restored = @src.ScalableCountingBloomFilter::from_bytes(
      combined.to_bytes(),
    )
    assert_eq(restored.count(), combined.count())
    assert_eq(restored.tracked_key_count(), combined.tracked_key_count())
    for key = 0; key < key_count; key = key + 1 {
      if live_left[key] > 0 || live_right[key] > 0 {
        assert_true(restored.contains(key))
      }
      assert_eq(restored.count_of(key), combined.count_of(key))
    }
    let restored_common = @src.ScalableCountingBloomFilter::from_bytes(
      common.to_bytes(),
    )
    assert_eq(restored_common.count(), common.count())
    for key = 0; key < key_count; key = key + 1 {
      assert_eq(restored_common.count_of(key), common.count_of(key))
    }
  }
}

///|
test "fuzz scalable counting set operations stay removable" {
  let key_count = 16
  for round = 1; round <= 150; round = round + 1 {
    let capacity = round % 4 + 1
    let rate = 0.02
    let left = @src.ScalableCountingBloomFilter::new(capacity, rate)
    let right = @src.ScalableCountingBloomFilter::new(capacity, rate)
    let live_left : Array[Int32] = Array::make(key_count, 0)
    let live_right : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 2654435 + 3
    for step = 0; step < 120; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let action = seed / 29 % 4
      if action == 0 {
        left.insert(key)
        live_left[key] = live_left[key] + 1
      } else if action == 1 {
        right.insert(key)
        live_right[key] = live_right[key] + 1
      } else if action == 2 && live_left[key] > 0 {
        assert_true(left.remove(key))
        live_left[key] = live_left[key] - 1
      } else if action == 3 && live_right[key] > 0 {
        assert_true(right.remove(key))
        live_right[key] = live_right[key] - 1
      }
    }
    let combined = left.union(right)
    for key = 0; key < key_count; key = key + 1 {
      if live_left[key] > 0 || live_right[key] > 0 {
        let occurrences = combined.count_of(key)
        assert_true(occurrences > 0)
        for j = 0; j < occurrences; j = j + 1 {
          assert_true(combined.remove(key))
        }
        assert_eq(combined.count_of(key), 0)
      }
    }
    let common = left.intersection(right)
    for key = 0; key < key_count; key = key + 1 {
      if live_left[key] > 0 && live_right[key] > 0 {
        let occurrences = common.count_of(key)
        assert_true(occurrences > 0)
        for j = 0; j < occurrences; j = j + 1 {
          assert_true(common.remove(key))
        }
        assert_eq(common.count_of(key), 0)
      }
    }
  }
}
