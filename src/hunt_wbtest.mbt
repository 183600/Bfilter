///|
fn hunt_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "hunt scalable counting union and merge multiplicities" {
  let layouts : Array[(Int32, Double)] = [(2, 0.05), (4, 0.01), (8, 0.5)]
  for layout in layouts {
    let (capacity, rate) = layout
    for round = 1; round <= 30; round = round + 1 {
      let left = ScalableCountingBloomFilter::new(capacity, rate)
      let right = ScalableCountingBloomFilter::new(capacity, rate)
      let keys = 30
      let left_live : Array[Int32] = Array::make(keys, 0)
      let right_live : Array[Int32] = Array::make(keys, 0)
      let mut seed = round * 977 + capacity
      for step = 0; step < 300; step = step + 1 {
        seed = hunt_seed(seed)
        let key = seed % keys
        let which = seed / 31 % 4
        if which == 0 {
          left.insert(key)
          left_live[key] = left_live[key] + 1
        } else if which == 1 {
          right.insert(key)
          right_live[key] = right_live[key] + 1
        } else if which == 2 {
          if left_live[key] > 0 {
            assert_true(left.remove(key))
            left_live[key] = left_live[key] - 1
          }
        } else {
          if right_live[key] > 0 {
            assert_true(right.remove(key))
            right_live[key] = right_live[key] - 1
          }
        }
      }
      let combined = left.union(right)
      let merged = left.copy()
      merged.merge(right)
      for key = 0; key < keys; key = key + 1 {
        let left_id = key_hashes(key)
        let right_id = key_hashes(key)
        let expected = match (left.locations.get(left_id), right.locations.get(right_id)) {
          (Some((ls, lo)), Some((rs, ro))) => if ls == rs { lo.max(ro) } else { lo + ro }
          (Some((_, lo)), None) => lo
          (None, Some((_, ro))) => ro
          (None, None) => 0
        }
        assert_eq(combined.count_of(key), expected)
        assert_eq(merged.count_of(key), expected)
      }
      let bytes = combined.to_bytes()
      let restored = ScalableCountingBloomFilter::from_bytes(bytes)
      assert_eq(restored.to_bytes(), bytes)
      for key = 0; key < keys; key = key + 1 {
        assert_eq(restored.count_of(key), combined.count_of(key))
      }
    }
  }
}

///|
test "hunt scalable counting intersection multiplicities and removability" {
  let layouts : Array[(Int32, Double)] = [(2, 0.05), (4, 0.01), (8, 0.5)]
  for layout in layouts {
    let (capacity, rate) = layout
    for round = 1; round <= 30; round = round + 1 {
      let left = ScalableCountingBloomFilter::new(capacity, rate)
      let right = ScalableCountingBloomFilter::new(capacity, rate)
      let keys = 30
      let left_live : Array[Int32] = Array::make(keys, 0)
      let right_live : Array[Int32] = Array::make(keys, 0)
      let mut seed = round * 1237 + capacity
      for step = 0; step < 300; step = step + 1 {
        seed = hunt_seed(seed)
        let key = seed % keys
        let which = seed / 31 % 4
        if which == 0 {
          left.insert(key)
          left_live[key] = left_live[key] + 1
        } else if which == 1 {
          right.insert(key)
          right_live[key] = right_live[key] + 1
        } else if which == 2 {
          if left_live[key] > 0 {
            assert_true(left.remove(key))
            left_live[key] = left_live[key] - 1
          }
        } else {
          if right_live[key] > 0 {
            assert_true(right.remove(key))
            right_live[key] = right_live[key] - 1
          }
        }
      }
      let common = left.intersection(right)
      for key = 0; key < keys; key = key + 1 {
        let expected = left_live[key].min(right_live[key])
        assert_eq(common.count_of(key), expected)
        for i = 0; i < expected; i = i + 1 {
          assert_true(common.remove(key))
        }
        assert_eq(common.count_of(key), 0)
      }
      assert_eq(common.count(), 0)
      assert_eq(common.tracked_key_count(), 0)
      let bytes = common.to_bytes()
      let restored = ScalableCountingBloomFilter::from_bytes(bytes)
      assert_eq(restored.to_bytes(), bytes)
    }
  }
}

///|
test "hunt drained tracked scalable slice stays serializable after insertion" {
  let filter = ScalableCountingBloomFilter::new(65536, 0.5)
  for i = 0; i < 65536; i = i + 1 {
    filter.insert("saturated")
  }
  for i = 0; i < 65535; i = i + 1 {
    assert_true(filter.remove("saturated"))
  }
  assert_false(filter.contains("saturated"))
  assert_eq(filter.count_of("saturated"), 1)
  filter.insert("fresh")
  assert_eq(filter.count_of("saturated"), 1)
  assert_eq(filter.count_of("fresh"), 1)
  let bytes = filter.to_bytes()
  let restored = ScalableCountingBloomFilter::from_bytes(bytes)
  assert_eq(restored.to_bytes(), bytes)
  assert_eq(restored.count_of("saturated"), 1)
  assert_eq(restored.count_of("fresh"), 1)
  assert_true(restored.contains("fresh"))
}

///|
test "hunt cuckoo union and merge agreement under high load" {
  let layouts : Array[(Int32, Int32)] = [(1, 1), (1, 4), (2, 2), (4, 1), (4, 4), (8, 2), (16, 4)]
  for layout in layouts {
    let (bucket_count, bucket_size) = layout
    for round = 1; round <= 25; round = round + 1 {
      let left = CuckooFilter::with_size(bucket_count, bucket_size)
      let right = CuckooFilter::with_size(bucket_count, bucket_size)
      let keys = (bucket_count * bucket_size * 2).max(8)
      let left_live : Array[Int32] = Array::make(keys, 0)
      let right_live : Array[Int32] = Array::make(keys, 0)
      let mut seed = round * 211 + bucket_count
      for step = 0; step < 200; step = step + 1 {
        seed = hunt_seed(seed)
        let key = seed % keys
        let which = seed / 31 % 4
        if which == 0 {
          if left.insert(key) {
            left_live[key] = left_live[key] + 1
          }
        } else if which == 1 {
          if right.insert(key) {
            right_live[key] = right_live[key] + 1
          }
        } else if which == 2 {
          if left_live[key] > 0 {
            assert_true(left.remove(key))
            left_live[key] = left_live[key] - 1
          }
        } else {
          if right_live[key] > 0 {
            assert_true(right.remove(key))
            right_live[key] = right_live[key] - 1
          }
        }
      }
      let before_left = left.to_bytes()
      let before_right = right.to_bytes()
      let union = left.union(right)
      let merged = left.copy()
      let merged_ok = merged.merge(right)
      match union {
        Some(joined) => {
          assert_true(merged_ok)
          assert_eq(merged.to_bytes(), joined.to_bytes())
          assert_eq(joined.count(), left.count() + right.count())
          for key = 0; key < keys; key = key + 1 {
            if left_live[key] > 0 || right_live[key] > 0 {
              assert_true(joined.contains(key))
            }
          }
          let restored = CuckooFilter::from_bytes(joined.to_bytes())
          assert_eq(restored.to_bytes(), joined.to_bytes())
        }
        None => {
          assert_false(merged_ok)
          assert_eq(left.to_bytes(), before_left)
          assert_eq(right.to_bytes(), before_right)
        }
      }
      let common = left.intersection(right)
      for key = 0; key < keys; key = key + 1 {
        if left_live[key] > 0 && right_live[key] > 0 {
          assert_true(common.contains(key))
        }
      }
      assert_true(common.is_subset_of(left))
      assert_true(common.is_subset_of(right))
      let restored_common = CuckooFilter::from_bytes(common.to_bytes())
      assert_eq(restored_common.to_bytes(), common.to_bytes())
    }
  }
}
