///|
test "concurrent bloom filter exposes atomic set operations" {
  let left = @src.ConcurrentBloomFilter::with_size(8192, 4)
  let right = @src.BloomFilter::with_size(8192, 4)
  left.insert("shared")
  left.insert("left-only")
  right.insert("shared")
  right.insert("right-only")
  let combined = left.union(right)
  assert_true(combined.contains("shared"))
  assert_true(combined.contains("left-only"))
  assert_true(combined.contains("right-only"))
  assert_eq(combined.count(), left.count() + right.count())
  assert_true(left.is_subset_of(combined))
  assert_eq(left.count(), 2)
  let common = left.intersection(right)
  assert_true(common.contains("shared"))
  assert_true(common.is_subset_of(left.snapshot()))
  assert_true(common.is_subset_of(right))
  assert_eq(common.count(), left.count().min(right.count()))
}

///|
test "concurrent counting filter exposes atomic set operations" {
  let left = @src.ConcurrentCountingBloomFilter::with_size(8192, 4)
  let right = @src.CountingBloomFilter::with_size(8192, 4)
  left.insert("shared")
  left.insert("shared")
  left.insert("left-only")
  right.insert("shared")
  right.insert("right-only")
  let combined = left.union(right)
  assert_true(combined.contains("left-only"))
  assert_true(combined.contains("right-only"))
  assert_eq(combined.count_of("shared"), 2)
  assert_eq(combined.count(), left.count() + right.count())
  assert_true(left.is_subset_of(combined))
  assert_eq(left.count(), 3)
  let common = left.intersection(right)
  assert_true(common.contains("shared"))
  assert_eq(common.count_of("shared"), 1)
  assert_true(common.is_subset_of(left.snapshot()))
  assert_true(common.is_subset_of(right))
}

///|
test "concurrent cuckoo filter exposes atomic set operations" {
  let left = @src.ConcurrentCuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  match left.union(right) {
    Some(combined) => {
      assert_true(combined.contains("left"))
      assert_true(combined.contains("right"))
      assert_eq(combined.count(), 2)
      assert_true(left.is_subset_of(combined))
      assert_true(right.is_subset_of(combined))
    }
    None => abort("combined filter unexpectedly full")
  }
  assert_eq(left.count(), 1)
  assert_true(right.insert("left"))
  assert_true(left.is_subset_of(right))
  assert_false(right.is_subset_of(left.snapshot()))
}
