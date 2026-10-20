///|
test "cuckoo union rejects layouts whose candidate buckets cannot fit" {
  let left = @src.CuckooFilter::with_size(4, 2)
  for key in [11, 9, 7] {
    assert_true(left.insert(key))
  }
  let right = @src.CuckooFilter::with_size(4, 2)
  for key in [20, 1, 39, 39, 2] {
    assert_true(right.insert(key))
  }
  assert_eq(left.count() + right.count(), left.capacity())
  assert_true(left.union(right) is None)
  assert_eq(left.count(), 3)
  assert_eq(right.count(), 5)
}
