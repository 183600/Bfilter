///|
test "bloom filter counter after saturated removal behavior" {
  let filter = @src.BloomFilter::with_size(64, 1)
  for i = 0; i < 10; i = i + 1 {
    filter.insert("overflow")
  }
  assert_eq(filter.count(), 10)
  filter.clear()
  assert_eq(filter.count(), 0)
  filter.insert("new")
  assert_true(filter.contains("new"))
}

///|
test "counting bloom filter remove on empty filter returns false" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  assert_false(filter.remove("nonexistent"))
  assert_eq(filter.count(), 0)
}

///|
test "compact counting bloom filter remove on empty filter returns false" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  assert_false(filter.remove("nonexistent"))
  assert_eq(filter.count(), 0)
}

///|
test "cuckoo filter remove on empty filter returns false" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  assert_false(filter.remove("nonexistent"))
  assert_eq(filter.count(), 0)
}

///|
test "bloom filter contains before any insertion is always false" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  assert_false(filter.contains("any-key"))
}

///|
test "counting bloom filter contains before any insertion is always false" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  assert_false(filter.contains("any-key"))
}

///|
test "cuckoo filter contains before any insertion is always false" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  assert_false(filter.contains("any-key"))
}

///|
test "bloom filter insert_after_clear works correctly" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("key1")
  filter.insert("key2")
  filter.clear()
  filter.insert("key3")
  assert_true(filter.contains("key3"))
  assert_false(filter.contains("key1"))
  assert_false(filter.contains("key2"))
}

///|
test "counting bloom filter insertion counter tracks duplicates" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  filter.insert("key")
  filter.insert("key")
  filter.insert("key")
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("key"), 3)
}

///|
test "compact counting bloom filter insertion counter tracks duplicates" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  filter.insert("key")
  filter.insert("key")
  filter.insert("key")
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("key"), 3)
}

///|
test "cuckoo filter insertion counter tracks duplicates" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  ignore(filter.insert("key"))
  ignore(filter.insert("key"))
  ignore(filter.insert("key"))
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("key"), 3)
}

///|
test "scalable bloom filter clear resets to initial state" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  filter.insert("a")
  for i = 0; i < 100; i = i + 1 {
    filter.insert(i.to_string())
  }
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 0)
  assert_true(filter.is_empty())
}

///|
test "scalable counting bloom filter clear resets to initial state" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("a")
  filter.insert("a")
  for i = 0; i < 100; i = i + 1 {
    filter.insert(i.to_string())
  }
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 0)
  assert_eq(filter.tracked_key_count(), 0)
  assert_true(filter.is_empty())
}

///|
test "bloom filter bit_count is multiple of 64" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  assert_eq(filter.bit_count() % 64, 0)
}

///|
test "blocked bloom filter bit_count is multiple of 512" {
  let filter = @src.BlockedBloomFilter::with_size(512, 4)
  assert_eq(filter.bit_count() % 512, 0)
}

///|
test "blocked bloom filter block_count calculation" {
  let filter = @src.BlockedBloomFilter::new(100, 0.01)
  assert_eq(filter.block_count(), filter.bit_count() / 512)
}

///|
test "cuckoo filter bucket count is power of two" {
  let filter = @src.CuckooFilter::new(100)
  let bc = filter.bucket_count()
  assert_eq(bc & (bc - 1), 0)
}

///|
test "cuckoo filter bucket_size is 4 by default" {
  let filter = @src.CuckooFilter::new(100)
  assert_eq(filter.bucket_size(), 4)
}

///|
test "concurrent bloom filter clear resets insertion count" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  filter.insert("key")
  filter.insert("key")
  filter.clear()
  assert_eq(filter.count(), 0)
  assert_true(filter.is_empty())
}

///|
test "concurrent counting bloom filter clear resets counters" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  filter.insert("key")
  filter.insert("key")
  filter.clear()
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.count(), 0)
  assert_eq(filter.count_of("key"), 0)
}

///|
test "concurrent cuckoo filter clear resets eviction state" {
  let filter = @src.ConcurrentCuckooFilter::new(64)
  ignore(filter.insert("key"))
  filter.clear()
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("key"))
}

///|
test "concurrent scalable bloom filter clear reuses initial slice" {
  let filter = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  for i = 0; i < 100; i = i + 1 {
    filter.insert(i.to_string())
  }
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 0)
  assert_true(filter.target_false_positive_rate() == 0.01)
}

///|
test "concurrent scalable counting bloom filter clear resets tracked keys" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("key")
  filter.insert("key")
  for i = 0; i < 50; i = i + 1 {
    filter.insert("other" + i.to_string())
  }
  filter.clear()
  assert_eq(filter.tracked_key_count(), 0)
  assert_eq(filter.count(), 0)
}

///|
test "concurrent bloom filter copy preserves bit_count and hash_count" {
  let original = @src.ConcurrentBloomFilter::with_size(2048, 5)
  let copy = original.copy()
  assert_eq(copy.bit_count(), original.bit_count())
  assert_eq(copy.hash_count(), original.hash_count())
}

///|
test "concurrent counting bloom filter copy preserves slot_count and hash_count" {
  let original = @src.ConcurrentCountingBloomFilter::with_size(2048, 5)
  let copy = original.copy()
  assert_eq(copy.slot_count(), original.slot_count())
  assert_eq(copy.hash_count(), original.hash_count())
}

///|
test "concurrent cuckoo filter copy preserves bucket_count and bucket_size" {
  let original = @src.ConcurrentCuckooFilter::with_size(128, 4)
  let copy = original.copy()
  assert_eq(copy.bucket_count(), original.bucket_count())
  assert_eq(copy.bucket_size(), original.bucket_size())
}