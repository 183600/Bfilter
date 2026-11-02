///|
test "concurrent compact counting filter union contains keys from both inputs" {
  let left = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let left_keys = ["a", "b", "c"]
  let right_keys = ["d", "e", "f"]
  left.insert_all(left_keys)
  right.insert_all(right_keys)
  let combined = left.union(right)
  assert_true(combined.contains_all(left_keys))
  assert_true(combined.contains_all(right_keys))
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  assert_eq(combined.count(), left.count() + right.count())
}

///|
test "concurrent compact counting filter intersection keeps keys present in both" {
  let left = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let shared = ["shared-1", "shared-2", "shared-3"]
  left.insert_all(shared)
  right.insert_all(shared)
  let common = left.intersection(right)
  assert_true(common.contains_all(shared))
  assert_true(common.is_subset_of(left.snapshot()))
  assert_true(common.is_subset_of(right))
  assert_eq(common.count(), left.count().min(right.count()))
}

///|
test "concurrent compact counting filter subset compares counters" {
  let once = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
  let twice = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
  let keys = ["alpha", "beta", "gamma"]
  once.insert_all(keys)
  twice.insert_all(keys)
  twice.insert_all(keys)
  let once_snapshot = once.snapshot()
  let twice_snapshot = twice.snapshot()
  assert_false(twice_snapshot.is_subset_of(once_snapshot))
  assert_true(once_snapshot.is_subset_of(twice_snapshot))
}

///|
test "concurrent compact counting filter is_disjoint_from detects no overlap" {
let left = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
assert_true(left.is_disjoint_from(right))

let with_overlap = @src.CompactCountingBloomFilter::with_size(8192, 4)
left.insert("shared")
with_overlap.insert("shared")
assert_false(left.is_disjoint_from(with_overlap))
}

///|
test "concurrent compact counting filter empty set operations" {
  let empty = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
  let filled = @src.CompactCountingBloomFilter::with_size(8192, 4)
  filled.insert("key")

  assert_true(empty.is_subset_of(filled))
  assert_true(filled.is_disjoint_from(empty.snapshot()))
  assert_true(empty.is_disjoint_from(filled))

  let union_result = empty.union(filled)
  assert_eq(union_result.count(), 1)
  assert_true(union_result.contains("key"))

  let intersection_result = filled.intersection(empty.snapshot())
  assert_true(intersection_result.is_empty())
  assert_eq(intersection_result.count(), 0)
}

///|
test "concurrent compact counting filter merge preserves counters" {
  let left = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
  left.insert("shared")
  left.insert("shared")
  left.merge(right)
  assert_eq(left.count_of("shared"), 2)
  assert_true(left.remove("shared"))
  assert_eq(left.count_of("shared"), 1)
}