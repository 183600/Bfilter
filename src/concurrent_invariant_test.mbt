///|
test "concurrent bloom filter snapshot is independent from original" {
  let original = @src.ConcurrentBloomFilter::with_size(1024, 4)
  original.insert("key1")
  original.insert("key2")
  let snapshot = original.snapshot()
  original.insert("key3")
  assert_true(snapshot.contains("key1"))
  assert_true(snapshot.contains("key2"))
  assert_false(snapshot.contains("key3"))
}

///|
test "concurrent counting bloom filter snapshot is independent" {
  let original = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  original.insert("key")
  original.insert("key")
  let snapshot = original.snapshot()
  assert_eq(snapshot.count_of("key"), 2)
  original.insert("key")
  assert_eq(original.count_of("key"), 3)
  assert_eq(snapshot.count_of("key"), 2)
}

///|
test "concurrent compact counting bloom filter snapshot is independent" {
  let original = @src.ConcurrentCompactCountingBloomFilter::with_size(1024, 4)
  original.insert("key")
  original.insert("key")
  let snapshot = original.snapshot()
  assert_eq(snapshot.count_of("key"), 2)
  original.insert("key")
  assert_eq(original.count_of("key"), 3)
  assert_eq(snapshot.count_of("key"), 2)
}

///|
test "concurrent blocked bloom filter snapshot is independent" {
  let original = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  original.insert("key1")
  original.insert("key2")
  let snapshot = original.snapshot()
  original.insert("key3")
  assert_true(snapshot.contains("key1"))
  assert_false(snapshot.contains("key3"))
}

///|
test "concurrent cuckoo filter snapshot is independent from original" {
  let original = @src.ConcurrentCuckooFilter::with_size(128, 4)
  ignore(original.insert("key1"))
  ignore(original.insert("key2"))
  let snapshot = original.snapshot()
  ignore(original.insert("key3"))
  assert_true(snapshot.contains("key1"))
  assert_false(snapshot.contains("key3"))
}

///|
test "concurrent scalable bloom filter snapshot preserves slice_count" {
  let original = @src.ConcurrentScalableBloomFilter::new(10, 0.01)
  for i = 0; i < 100; i = i + 1 {
    original.insert(i.to_string())
  }
  let slice_count = original.slice_count()
  let snapshot = original.snapshot()
  assert_eq(snapshot.slice_count(), slice_count)
  assert_eq(snapshot.count(), original.count())
  for i = 0; i < 100; i = i + 1 {
    assert_true(snapshot.contains(i.to_string()))
  }
  original.insert("new")
  assert_false(snapshot.contains("new"))
}

///|
test "concurrent scalable counting bloom filter snapshot preserves state" {
  let original = @src.ConcurrentScalableCountingBloomFilter::new(10, 0.01)
  original.insert("key1")
  original.insert("key1")
  original.insert("key2")
  for i = 0; i < 10; i = i + 1 {
    original.insert("extra" + i.to_string())
  }
  let snapshot = original.snapshot()
  assert_eq(snapshot.count_of("key1"), 2)
  assert_eq(snapshot.count_of("key2"), 1)
  assert_eq(snapshot.tracked_key_count(), 12)
  original.insert("key3")
  assert_false(snapshot.contains("key3"))
}

///|
test "concurrent bloom filter copy returns independent bloom filter" {
  let filter = @src.ConcurrentBloomFilter::with_size(256, 3)
  filter.insert("a")
  filter.insert("b")
  let copy = filter.copy()
  assert_true(copy.contains("a"))
  assert_true(copy.contains("b"))
  filter.insert("c")
  assert_false(copy.contains("c"))
}

///|
test "concurrent blocking bloom filter copy returns same layout" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(512, 4)
  filter.insert("a")
  let copy = filter.copy()
  assert_eq(copy.bit_count(), filter.bit_count())
  assert_eq(copy.hash_count(), filter.hash_count())
}

///|
test "concurrent cuckoo filter copy returns same layout" {
  let filter = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(filter.insert("a"))
  let copy = filter.copy()
  assert_eq(copy.bucket_count(), filter.bucket_count())
  assert_eq(copy.bucket_size(), filter.bucket_size())
}

///|
test "concurrent scalable bloom filter copy preserves all slices" {
  let original = @src.ConcurrentScalableBloomFilter::new(10, 0.01)
  for i = 0; i < 500; i = i + 1 {
    original.insert(i.to_string())
  }
  let copy = original.copy()
  assert_eq(copy.count(), original.count())
  assert_eq(copy.slice_count(), original.slice_count())
  for i = 0; i < 500; i = i + 1 {
    assert_true(copy.contains(i.to_string()))
  }
}

///|
test "concurrent scalable counting bloom filter copy preserves metadata" {
  let original = @src.ConcurrentScalableCountingBloomFilter::new(10, 0.01)
  original.insert("tracked")
  original.insert("tracked")
  let copy = original.copy()
  assert_eq(copy.tracked_key_count(), original.tracked_key_count())
  assert_eq(copy.count_of("tracked"), original.count_of("tracked"))
}

///|
test "concurrent bloom filter merge from empty returns unchanged" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  filter.insert("existing")
  let empty = @src.BloomFilter::with_size(1024, 4)
  filter.merge(empty)
  assert_true(filter.contains("existing"))
  assert_eq(filter.count(), 1)
}

///|
test "concurrent counting bloom filter merge from empty returns unchanged" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  filter.insert("existing")
  filter.insert("existing")
  let empty = @src.CountingBloomFilter::with_size(1024, 4)
  filter.merge(empty)
  assert_eq(filter.count_of("existing"), 2)
}

///|
test "concurrent cuckoo filter clear resets to empty" {
  let filter = @src.ConcurrentCuckooFilter::new(100)
  ignore(filter.insert("key"))
  assert_false(filter.is_empty())
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("key"))
}

///|
test "concurrent scalable bloom filter clear resets to initial capacity" {
  let filter = @src.ConcurrentScalableBloomFilter::new(10, 0.01)
  for i = 0; i < 100; i = i + 1 {
    filter.insert(i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_true(filter.target_false_positive_rate() == 0.01)
}

///|
test "concurrent scalable counting bloom filter clear resets tracked keys" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(10, 0.01)
  filter.insert("key1")
  filter.insert("key2")
  for i = 0; i < 50; i = i + 1 {
    filter.insert("extra" + i.to_string())
  }
  assert_true(filter.tracked_key_count() > 0)
  filter.clear()
  assert_eq(filter.tracked_key_count(), 0)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}