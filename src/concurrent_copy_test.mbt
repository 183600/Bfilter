///|
test "concurrent bloom filter copy is independent" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  filter.insert("before")
  let copy = filter.copy()
  assert_eq(copy.to_bytes(), filter.to_bytes())
  filter.insert("after")
  assert_eq(copy.count(), 1)
  assert_false(copy.contains("after"))
  copy.insert("copy-only")
  assert_false(filter.contains("copy-only"))
}

///|
test "concurrent blocked bloom filter copy is independent" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  filter.insert("before")
  let copy = filter.copy()
  assert_eq(copy.to_bytes(), filter.to_bytes())
  filter.insert("after")
  assert_eq(copy.count(), 1)
  assert_false(copy.contains("after"))
  copy.clear()
  assert_true(filter.contains("before"))
  assert_true(copy.is_empty())
}

///|
test "concurrent counting filter copy is independent" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  filter.insert("value")
  filter.insert("value")
  let copy = filter.copy()
  assert_eq(copy.to_bytes(), filter.to_bytes())
  assert_eq(copy.count_of("value"), 2)
  assert_true(filter.remove("value"))
  assert_eq(filter.count_of("value"), 1)
  assert_eq(copy.count_of("value"), 2)
  assert_true(copy.remove("value"))
  assert_eq(copy.count_of("value"), 1)
}

///|
test "concurrent compact counting filter copy is independent" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::with_size(1024, 4)
  filter.insert("value")
  filter.insert("value")
  let copy = filter.copy()
  assert_eq(copy.to_bytes(), filter.to_bytes())
  assert_eq(copy.count_of("value"), 2)
  assert_true(filter.remove("value"))
  assert_eq(filter.count_of("value"), 1)
  assert_eq(copy.count_of("value"), 2)
  assert_true(copy.remove("value"))
  assert_eq(copy.count_of("value"), 1)
}

///|
test "concurrent cuckoo filter copy is independent" {
  let filter = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_true(filter.insert("before"))
  let copy = filter.copy()
  assert_eq(copy.to_bytes(), filter.to_bytes())
  assert_true(filter.insert("after"))
  assert_eq(copy.count(), 1)
  assert_false(copy.contains("after"))
  assert_true(copy.remove("before"))
  assert_true(filter.contains("before"))
}

///|
test "concurrent scalable bloom filter copy is independent" {
  let filter = @src.ConcurrentScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let copy = filter.copy()
  assert_eq(copy.to_bytes(), filter.to_bytes())
  let slices = copy.slice_count()
  filter.insert("after")
  assert_eq(copy.count(), 20)
  assert_eq(copy.slice_count(), slices)
  assert_false(copy.contains("after"))
  copy.clear()
  assert_eq(copy.slice_count(), 1)
  assert_true(copy.is_empty())
  assert_true(filter.contains("key-0"))
}

///|
test "concurrent scalable counting filter copy is independent" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  filter.insert("key-0")
  let copy = filter.copy()
  assert_eq(copy.to_bytes(), filter.to_bytes())
  assert_eq(copy.count_of("key-0"), 2)
  assert_true(filter.remove("key-0"))
  assert_eq(filter.count_of("key-0"), 1)
  assert_eq(copy.count_of("key-0"), 2)
  assert_true(copy.remove("key-0"))
  assert_eq(copy.count_of("key-0"), 1)
  assert_eq(copy.tracked_key_count(), 20)
}
