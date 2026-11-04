///|
test "compact counting filter batch operations handle empty batches" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  let empty : Array[String] = []
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))
  assert_eq(filter.count(), 0)
}

///|
test "compact counting filter remove_all reports partial failures" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert_all(["a", "b"])
  assert_false(filter.remove_all(["a", "missing"]))
  assert_false(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_eq(filter.count(), 1)
}

///|
test "compact counting filter set operations with empty operands" {
  let left = @src.CompactCountingBloomFilter::with_size(256, 4)
  let right = @src.CompactCountingBloomFilter::with_size(256, 4)
  left.insert("shared")
  right.insert("shared")
  assert_true(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_false(left.is_disjoint_from(right))
  
  let empty = @src.CompactCountingBloomFilter::with_size(256, 4)
  assert_true(empty.is_subset_of(left))
  assert_true(empty.is_disjoint_from(left))
  
  let empty_union = left.union(empty)
  assert_true(empty_union.contains("shared"))
  assert_eq(empty_union.count(), 1)
  
  let empty_intersection = left.intersection(empty)
  assert_true(empty_intersection.is_empty())
  assert_eq(empty_intersection.count(), 0)
}