///|
test "scalable bloom empty filters answer subset and disjoint checks without slices" {
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
test "scalable counting empty filters answer subset and disjoint checks without slices" {
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
