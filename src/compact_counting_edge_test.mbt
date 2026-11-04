///|
test "compact counting filter batch operations handle empty batches" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  let empty : Array[String] = []
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))
  assert_eq(filter.count(), 0)
}

///|
test "compact counting filter is_subset_of with empty operands" {
  let left = @src.CompactCountingBloomFilter::with_size(256, 4)
  let right = @src.CompactCountingBloomFilter::with_size(256, 4)
  left.insert("shared")
  right.insert("shared")
  assert_true(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_false(left.is_disjoint_from(right))
}

///|
test "compact counting filter union empty preserves source" {
  let left = @src.CompactCountingBloomFilter::with_size(256, 4)
  left.insert("alpha")
  let empty = @src.CompactCountingBloomFilter::with_size(256, 4)
  let union = left.union(empty)
  assert_true(union.contains("alpha"))
  assert_false(empty.contains("alpha"))
}

///|
test "compact counting filter intersection empty yields empty result" {
  let left = @src.CompactCountingBloomFilter::with_size(256, 4)
  left.insert("key")
  let empty = @src.CompactCountingBloomFilter::with_size(256, 4)
  let intersection = left.intersection(empty)
  assert_true(intersection.is_empty())
  assert_eq(intersection.count(), 0)
}