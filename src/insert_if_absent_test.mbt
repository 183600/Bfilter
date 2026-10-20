///|
test "bloom filter inserts only when the key is definitely absent" {
  let filter = @src.BloomFilter::with_size(4096, 4)
  assert_true(filter.insert_if_absent("value"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("value"))
  assert_eq(filter.count(), 1)
  filter.clear()
  assert_true(filter.insert_if_absent("value"))
  assert_eq(filter.count(), 1)
}

///|
test "counting filter inserts only when a counter is free" {
  let filter = @src.CountingBloomFilter::with_size(4096, 4)
  assert_true(filter.insert_if_absent("value"))
  assert_false(filter.insert_if_absent("value"))
  assert_eq(filter.count_of("value"), 1)
  filter.insert("value")
  assert_eq(filter.count_of("value"), 2)
  assert_false(filter.insert_if_absent("value"))
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("value"))
  assert_true(filter.remove("value"))
  assert_eq(filter.count(), 0)
  assert_true(filter.insert_if_absent("value"))
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo filter inserts only when the fingerprint is absent" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  assert_true(filter.insert_if_absent("value"))
  assert_false(filter.insert_if_absent("value"))
  assert_eq(filter.count_of("value"), 1)
  assert_true(filter.remove("value"))
  assert_true(filter.insert_if_absent("value"))
  assert_eq(filter.count_of("value"), 1)
}

///|
test "concurrent wrappers expose atomic insert_if_absent" {
  let bloom = @src.ConcurrentBloomFilter::with_size(4096, 4)
  assert_true(bloom.insert_if_absent("value"))
  assert_false(bloom.insert_if_absent("value"))
  assert_eq(bloom.count(), 1)
  let counting = @src.ConcurrentCountingBloomFilter::with_size(4096, 4)
  assert_true(counting.insert_if_absent("value"))
  assert_false(counting.insert_if_absent("value"))
  assert_eq(counting.count(), 1)
  let cuckoo = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_true(cuckoo.insert_if_absent("value"))
  assert_false(cuckoo.insert_if_absent("value"))
  assert_eq(cuckoo.count(), 1)
}
