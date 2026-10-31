///|
test "count-only scalable counting filters are disjoint" {
  let left = ScalableCountingBloomFilter::new(2, 0.01)
  left.append_slice()
  left.slices[0].inserted = 2
  left.slices[1].inserted = 3
  left.inserted = 5
  assert_eq(left.occupied_slot_count(), 0L)

  let right = ScalableCountingBloomFilter::new(2, 0.01)
  right.insert("tracked")
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))

  let other_count_only = ScalableCountingBloomFilter::new(2, 0.01)
  other_count_only.append_slice()
  other_count_only.slices[0].inserted = 1
  other_count_only.slices[1].inserted = 1
  other_count_only.inserted = 2
  assert_true(left.is_disjoint_from(other_count_only))
  assert_true(other_count_only.is_disjoint_from(left))
  assert_true(left.is_subset_of(right))
  assert_true(left.is_subset_of(other_count_only))
}
