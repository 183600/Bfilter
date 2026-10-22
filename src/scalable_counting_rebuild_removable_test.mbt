///|
fn rebuild_test_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "scalable counting rebuilt merges keep every tracked occurrence removable" {
  let key_count = 10
  for round = 1; round <= 20; round = round + 1 {
    let left = @src.ScalableCountingBloomFilter::new(2, 0.01)
    let right = @src.ScalableCountingBloomFilter::new(2, 0.01)
    let mut seed = round * 7919 + 17
    for step = 0; step < 120; step = step + 1 {
      seed = rebuild_test_seed(seed)
      let key = seed % key_count
      if seed / 31 % 2 == 0 {
        left.insert(key)
      } else {
        right.insert(key)
      }
    }
    let merged = left.copy()
    merged.merge(right)
    assert_true(left.is_subset_of(merged))
    assert_true(right.is_subset_of(merged))
    assert_true(merged.count() <= left.count() + right.count())
    assert_eq(
      @src.ScalableCountingBloomFilter::from_bytes(merged.to_bytes()).to_bytes(),
      merged.to_bytes(),
    )
    for key = 0; key < key_count; key = key + 1 {
      let merged_occurrences = merged.count_of(key)
      assert_true(merged_occurrences >= left.count_of(key))
      assert_true(merged_occurrences >= right.count_of(key))
      assert_true(
        merged_occurrences <= left.count_of(key) + right.count_of(key),
      )
      for i = 0; i < merged_occurrences; i = i + 1 {
        assert_true(merged.remove(key))
      }
      assert_eq(merged.count_of(key), 0)
    }
    assert_eq(merged.count(), 0)
    assert_eq(merged.tracked_key_count(), 0)
    assert_eq(merged.occupied_slot_count(), 0L)
    let restored = @src.ScalableCountingBloomFilter::from_bytes(
      merged.to_bytes(),
    )
    assert_eq(restored.count(), 0)
    assert_eq(restored.tracked_key_count(), 0)
  }
}

///|
test "scalable counting rebuilt intersections keep every shared occurrence removable" {
  let key_count = 10
  for round = 1; round <= 20; round = round + 1 {
    let left = @src.ScalableCountingBloomFilter::new(2, 0.01)
    let right = @src.ScalableCountingBloomFilter::new(2, 0.01)
    let mut seed = round * 3571 + 3
    for step = 0; step < 120; step = step + 1 {
      seed = rebuild_test_seed(seed)
      let key = seed % key_count
      let which = seed / 31 % 3
      if which == 0 {
        left.insert(key)
      } else if which == 1 {
        right.insert(key)
      } else {
        left.insert(key)
        right.insert(key)
      }
    }
    let common = left.intersection(right)
    assert_true(common.is_subset_of(left))
    assert_true(common.is_subset_of(right))
    assert_eq(
      @src.ScalableCountingBloomFilter::from_bytes(common.to_bytes()).to_bytes(),
      common.to_bytes(),
    )
    for key = 0; key < key_count; key = key + 1 {
      let expected = left.count_of(key).min(right.count_of(key))
      assert_eq(common.count_of(key), expected)
      for i = 0; i < expected; i = i + 1 {
        assert_true(common.remove(key))
      }
      assert_eq(common.count_of(key), 0)
    }
    assert_eq(common.count(), 0)
    assert_eq(common.tracked_key_count(), 0)
    assert_eq(common.occupied_slot_count(), 0L)
    let restored = @src.ScalableCountingBloomFilter::from_bytes(
      common.to_bytes(),
    )
    assert_eq(restored.count(), 0)
    assert_eq(restored.tracked_key_count(), 0)
  }
}
