///|
test "scalable bloom empty filters answer subset and disjoint checks with several empty slices" {
  let left = ScalableBloomFilter::new(1024, 0.01)
  let right = ScalableBloomFilter::new(1024, 0.01)
  for i = 0; i < 4; i = i + 1 {
    left.append_slice()
    right.append_slice()
  }
  assert_true(left.is_empty())
  assert_true(right.is_empty())
  assert_true(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
  let filled = ScalableBloomFilter::new(1024, 0.01)
  filled.insert("present")
  assert_true(left.is_subset_of(filled))
  assert_true(left.is_disjoint_from(filled))
  assert_true(filled.is_disjoint_from(left))
}

///|
test "scalable counting empty filters answer subset and disjoint checks with several empty slices" {
  let left = ScalableCountingBloomFilter::new(1024, 0.01)
  let right = ScalableCountingBloomFilter::new(1024, 0.01)
  for i = 0; i < 4; i = i + 1 {
    left.append_slice()
    right.append_slice()
  }
  assert_eq(left.tracked_key_count(), 0)
  assert_true(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
  let filled = ScalableCountingBloomFilter::new(1024, 0.01)
  filled.insert("present")
  assert_true(left.is_subset_of(filled))
  assert_true(left.is_disjoint_from(filled))
  assert_true(filled.is_disjoint_from(left))
}

///|
test "scalable count-only slices remain empty for set checks" {
  // A count-only filter carries a conservative insertion count but no set bit
  // or positive counter. Its slices must still be treated as empty even though
  // their insertion count is positive, so the zero-count scan shortcut cannot
  // be widened to a count-only shortcut.
  let bloom : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  let restored_bloom = ScalableBloomFilter::from_bytes(bloom.to_bytes())
  assert_eq(restored_bloom.count(), 5)
  assert_eq(restored_bloom.set_bit_count(), 0)
  let filled_bloom = ScalableBloomFilter::new(2, 0.01)
  filled_bloom.insert("present")
  assert_true(restored_bloom.is_subset_of(filled_bloom))
  assert_true(restored_bloom.is_disjoint_from(filled_bloom))

  let counting : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  let restored_counting = ScalableCountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_eq(restored_counting.count(), 5)
  assert_eq(restored_counting.occupied_slot_count(), 0L)
  let filled_counting = ScalableCountingBloomFilter::new(2, 0.01)
  filled_counting.insert("present")
  assert_true(restored_counting.is_subset_of(filled_counting))
  assert_true(restored_counting.is_disjoint_from(filled_counting))
}
