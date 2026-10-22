///|
test "merging an empty bloom filter leaves the receiver unchanged" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert_all(["alpha", "beta"])
  let before = filter.to_bytes()
  let count = filter.count()
  let empty = @src.BloomFilter::with_size(1024, 4)
  filter.merge(empty)
  assert_eq(filter.to_bytes(), before)
  assert_eq(filter.count(), count)
  assert_true(filter.contains_all(["alpha", "beta"]))
}

///|
test "merging an empty blocked bloom filter leaves the receiver unchanged" {
  let filter = @src.BlockedBloomFilter::with_size(1024, 4)
  filter.insert_all(["alpha", "beta"])
  let before = filter.to_bytes()
  let count = filter.count()
  let empty = @src.BlockedBloomFilter::with_size(1024, 4)
  filter.merge(empty)
  assert_eq(filter.to_bytes(), before)
  assert_eq(filter.count(), count)
  assert_true(filter.contains_all(["alpha", "beta"]))
}

///|
test "merging an empty counting filter leaves counters unchanged" {
  let filter = @src.CountingBloomFilter::with_size(64, 4)
  filter.insert_all(["alpha", "alpha", "beta"])
  let before = filter.to_bytes()
  let count = filter.count()
  let empty = @src.CountingBloomFilter::with_size(64, 4)
  filter.merge(empty)
  assert_eq(filter.to_bytes(), before)
  assert_eq(filter.count(), count)
  assert_eq(filter.count_of("alpha"), 2)
}

///|
test "merging an empty compact counting filter leaves counters unchanged" {
  let filter = @src.CompactCountingBloomFilter::with_size(64, 4)
  filter.insert_all(["alpha", "alpha", "beta"])
  let before = filter.to_bytes()
  let count = filter.count()
  let empty = @src.CompactCountingBloomFilter::with_size(64, 4)
  filter.merge(empty)
  assert_eq(filter.to_bytes(), before)
  assert_eq(filter.count(), count)
  assert_eq(filter.count_of("alpha"), 2)
}

///|
test "merging an empty cuckoo filter succeeds without changing fingerprints" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  assert_true(filter.insert_all(["alpha", "beta"]))
  let before = filter.to_bytes()
  let count = filter.count()
  let empty = @src.CuckooFilter::with_size(64, 4)
  assert_true(filter.merge(empty))
  assert_eq(filter.to_bytes(), before)
  assert_eq(filter.count(), count)
  assert_true(filter.contains_all(["alpha", "beta"]))
}

///|
test "concurrent wrappers keep their receiver when merging an empty filter" {
  let bloom = @src.ConcurrentBloomFilter::with_size(1024, 4)
  bloom.insert("alpha")
  let bloom_before = bloom.to_bytes()
  bloom.merge(@src.BloomFilter::with_size(1024, 4))
  assert_eq(bloom.to_bytes(), bloom_before)
  assert_true(bloom.contains("alpha"))

  let cuckoo = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_true(cuckoo.insert("alpha"))
  let cuckoo_before = cuckoo.to_bytes()
  assert_true(cuckoo.merge(@src.CuckooFilter::with_size(64, 4)))
  assert_eq(cuckoo.to_bytes(), cuckoo_before)
  assert_true(cuckoo.contains("alpha"))
}

///|
test "merging a non-empty counting filter into an empty receiver copies it" {
  let source = @src.CountingBloomFilter::with_size(64, 4)
  source.insert_all(["alpha", "alpha", "beta"])
  let source_bytes = source.to_bytes()
  let receiver = @src.CountingBloomFilter::with_size(64, 4)
  receiver.merge(source)
  assert_eq(receiver.to_bytes(), source_bytes)
  assert_eq(receiver.count(), source.count())
  assert_eq(receiver.count_of("alpha"), 2)
  assert_eq(source.to_bytes(), source_bytes)
}

///|
test "merging a non-empty compact counting filter into an empty receiver copies it" {
  let source = @src.CompactCountingBloomFilter::with_size(64, 4)
  source.insert_all(["alpha", "alpha", "beta"])
  let source_bytes = source.to_bytes()
  let receiver = @src.CompactCountingBloomFilter::with_size(64, 4)
  receiver.merge(source)
  assert_eq(receiver.to_bytes(), source_bytes)
  assert_eq(receiver.count(), source.count())
  assert_eq(receiver.count_of("alpha"), 2)
  assert_eq(source.to_bytes(), source_bytes)
}
