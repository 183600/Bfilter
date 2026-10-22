///|
test "cuckoo subset rejects equal-count filters with different fingerprints" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("left-a"))
  assert_true(left.insert("left-b"))
  assert_true(right.insert("right-a"))
  assert_true(right.insert("right-b"))
  assert_eq(left.count(), right.count())
  assert_false(left.is_subset_of(right))
  assert_false(right.is_subset_of(left))
}
