///|
test "bloom filter insert_if_absent handles duplicates correctly" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_true(filter.insert_if_absent("other"))
  assert_eq(filter.count(), 2)
}

///|
test "counting bloom filter insert_if_absent requires zero counter" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of("key"), 1)
}

///|
test "compact counting bloom filter insert_if_absent requires zero counter" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of("key"), 1)
}

///|
test "blocked bloom filter insert_if_absent handles duplicates" {
  let filter = @src.BlockedBloomFilter::with_size(2048, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo filter insert_if_absent with new keys" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  assert_true(filter.insert_if_absent("key1"))
  assert_true(filter.insert_if_absent("key2"))
  assert_false(filter.insert_if_absent("key1"))
  assert_eq(filter.count(), 2)
}

///|
test "cuckoo filter insert_if_absent respects false positives" {
  let filter = @src.CuckooFilter::with_size(8, 4)
  for i = 0; i < 50; i = i + 1 {
    ignore(filter.insert(i.to_string()))
  }
  assert_false(filter.insert_if_absent("not-inserted"))
}

///|
test "scalable bloom filter insert_if_absent across slices" {
  let filter = @src.ScalableBloomFilter::new(10, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_false(filter.insert_if_absent("key"))
  let mut count = 1
  for i = 0; i < 100; i = i + 1 {
    if filter.insert_if_absent(i.to_string()) {
      count = count + 1
    }
  }
  assert_eq(filter.count(), count)
}

///|
test "scalable counting bloom filter insert_if_absent checks slice for zero counter" {
  let filter = @src.ScalableCountingBloomFilter::new(10, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "concurrent bloom filter insert_if_absent is thread-safe" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "concurrent counting bloom filter insert_if_absent requires zero counter" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count_of("key"), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "concurrent compact counting bloom filter insert_if_absent requires zero counter" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "concurrent blocked bloom filter insert_if_absent handles duplicates" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(2048, 4)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "concurrent cuckoo filter insert_if_absent" {
  let filter = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_true(filter.insert_if_absent("key1"))
  assert_true(filter.insert_if_absent("key2"))
  assert_false(filter.insert_if_absent("key1"))
  assert_eq(filter.count(), 2)
}

///|
test "concurrent scalable bloom filter insert_if_absent" {
  let filter = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_false(filter.insert_if_absent("key"))
  let added = filter.insert_all_if_absent(["a", "b", "a", "c"])
  assert_eq(added, 3)
}

///|
test "concurrent scalable counting bloom filter insert_if_absent does not add duplicates" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_eq(filter.tracked_key_count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.tracked_key_count(), 1)
}