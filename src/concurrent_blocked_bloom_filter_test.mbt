///|
test "concurrent blocked bloom filter insert and query" {
  let filter = @src.ConcurrentBlockedBloomFilter::new(200, 0.01)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  filter.insert("alpha")
  filter.insert(42)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 2)
  filter.clear()
  assert_true(filter.is_empty())
  assert_false(filter.contains("alpha"))
}

///|
test "concurrent blocked bloom filter batch operations share one lock" {
  let keys = ["a", "b", "c", "d"]
  let filter = @src.ConcurrentBlockedBloomFilter::new(100, 0.001)
  filter.insert_all(keys)
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  assert_false(filter.contains("missing"))
  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_true(filter.contains_all(empty))
  assert_true(filter.contains_any(keys))
  assert_false(filter.contains_any(empty))
  assert_eq(filter.count(), keys.length())
}

///|
test "concurrent blocked bloom filter reports layout statistics" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 5)
  assert_eq(filter.bit_count(), 1024)
  assert_eq(filter.block_count(), 2)
  assert_eq(filter.hash_count(), 5)
  assert_eq(filter.memory_bytes(), 128L)
  assert_eq(filter.false_positive_rate(), 0.0)
  filter.insert("value")
  assert_true(filter.set_bit_count() > 0)
  let rate = filter.false_positive_rate()
  assert_true(rate > 0.0 && rate < 1.0)
  assert_true(filter.estimated_item_count() > 0.0)
}

///|
test "concurrent blocked bloom filter snapshots and set operations" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  filter.insert("before")
  let snapshot = filter.snapshot()
  filter.insert("after")
  assert_eq(snapshot.count(), 1)
  assert_true(snapshot.contains("before"))

  let other = @src.BlockedBloomFilter::with_size(1024, 4)
  other.insert("other")
  let combined = filter.union(other)
  assert_true(combined.contains("before"))
  assert_true(combined.contains("other"))
  assert_true(filter.is_subset_of(combined))
  assert_true(filter.is_disjoint_from(other))
  filter.merge(other)
  assert_true(filter.contains("other"))
  let common = filter.intersection(other)
  assert_true(common.is_subset_of(other))
}

///|
test "concurrent blocked bloom filter serialization uses the lock" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  filter.insert("saved")
  let restored = @src.ConcurrentBlockedBloomFilter::from_bytes(
    filter.to_bytes(),
  )
  assert_true(restored.contains("saved"))
  assert_eq(restored.count(), 1)
  assert_eq(restored.bit_count(), filter.bit_count())
  assert_eq(restored.block_count(), filter.block_count())
}

///|
test "panic concurrent blocked bloom filter rejects invalid configuration" {
  @src.ConcurrentBlockedBloomFilter::new(0, 0.01) |> ignore
}
