///|
test "concurrent compact counting filter supports basic operations" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::new(100, 0.01)
  filter.insert("alpha")
  filter.insert("alpha")
  filter.insert("beta")
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("alpha"), 2)
  assert_true(filter.contains_all(["alpha", "beta"]))
  assert_true(filter.contains_any(["missing", "beta"]))
  assert_true(filter.remove("alpha"))
  assert_eq(filter.count_of("alpha"), 1)
  assert_false(filter.is_empty())
  filter.clear()
  assert_true(filter.is_empty())
  assert_false(filter.contains("beta"))
}

///|
test "concurrent compact counting filter batch and set operations" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::with_size(1024, 3)
  let other = @src.CompactCountingBloomFilter::with_size(1024, 3)
  other.insert_all(["x", "y"])
  assert_eq(filter.insert_all_if_absent(["a", "b", "c"]), 3)
  assert_eq(filter.insert_all_if_absent(["a", "b"]), 0)
  filter.merge(other)
  assert_true(filter.contains_all(["a", "b", "c", "x", "y"]))
  assert_eq(filter.count(), 5)
  let union = filter.union(other)
  assert_eq(union.count(), filter.count() + other.count())
  assert_true(filter.is_subset_of(union))
  let common = filter.intersection(other)
  assert_true(common.contains("x"))
  assert_false(common.contains("a"))
}

///|
test "concurrent compact counting filter snapshot is independent" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::new(50, 0.01)
  filter.insert("base")
  let snapshot = filter.snapshot()
  snapshot.insert("snapshot-only")
  assert_false(filter.contains("snapshot-only"))
  filter.insert("filter-only")
  assert_false(snapshot.contains("filter-only"))
  assert_eq(snapshot.memory_bytes(), filter.memory_bytes())
}

///|
test "concurrent compact counting filter serialization round trip" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::new(50, 0.01)
  filter.insert_all(["a", "b", "c"])
  let restored = @src.ConcurrentCompactCountingBloomFilter::from_bytes(
    filter.to_bytes(),
  )
  assert_eq(restored.count(), filter.count())
  assert_true(restored.contains_all(["a", "b", "c"]))
  assert_eq(restored.slot_count(), filter.slot_count())
  assert_eq(restored.hash_count(), filter.hash_count())
  assert_true(restored.false_positive_rate() > 0.0)
  assert_true(restored.fill_ratio() > 0.0)
  assert_true(restored.estimated_item_count() > 0.0)
}
