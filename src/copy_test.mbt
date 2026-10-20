///|
test "bloom filter copy is independent" {
  let original = @src.BloomFilter::with_size(1024, 4)
  original.insert("original")
  let copy = original.copy()
  assert_true(copy.contains("original"))
  copy.insert("copy")
  assert_eq(original.count(), 1)
  assert_eq(copy.count(), 2)
  original.clear()
  assert_eq(original.count(), 0)
  assert_eq(copy.count(), 2)
  assert_true(copy.contains("original"))
}

///|
test "counting filter copy is independent" {
  let original = @src.CountingBloomFilter::with_size(1024, 4)
  original.insert("value")
  let copy = original.copy()
  assert_true(copy.remove("value"))
  assert_false(copy.contains("value"))
  assert_true(original.contains("value"))
  assert_eq(original.count(), 1)
  assert_eq(copy.count(), 0)
  original.insert("extra")
  assert_eq(original.count(), 2)
  assert_eq(copy.count(), 0)
}

///|
test "cuckoo filter copy is independent" {
  let original = @src.CuckooFilter::with_size(64, 4)
  assert_true(original.insert("value"))
  let copy = original.copy()
  assert_true(copy.remove("value"))
  assert_false(copy.contains("value"))
  assert_true(original.contains("value"))
  assert_eq(original.count(), 1)
  assert_eq(copy.count(), 0)
  assert_true(original.insert("extra"))
  assert_eq(original.count(), 2)
  assert_eq(copy.count(), 0)
}

///|
test "concurrent bloom snapshot is consistent and independent" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  filter.insert("before")
  let snapshot = filter.snapshot()
  filter.insert("after")
  assert_eq(snapshot.count(), 1)
  assert_eq(filter.count(), 2)
  assert_true(snapshot.contains("before"))
  snapshot.insert("snapshot-only")
  assert_eq(filter.count(), 2)
  assert_eq(snapshot.count(), 2)
}

///|
test "concurrent counting snapshot is consistent and independent" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  filter.insert("before")
  let snapshot = filter.snapshot()
  filter.insert("after")
  assert_eq(snapshot.count(), 1)
  assert_eq(filter.count(), 2)
  assert_true(snapshot.remove("before"))
  assert_true(filter.contains("before"))
  assert_eq(snapshot.count(), 0)
  assert_eq(filter.count(), 2)
}

///|
test "concurrent cuckoo snapshot is consistent and independent" {
  let filter = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_true(filter.insert("before"))
  let snapshot = filter.snapshot()
  assert_true(filter.insert("after"))
  assert_eq(snapshot.count(), 1)
  assert_eq(filter.count(), 2)
  assert_true(snapshot.remove("before"))
  assert_true(filter.contains("before"))
  assert_eq(snapshot.count(), 0)
  assert_eq(filter.count(), 2)
}
