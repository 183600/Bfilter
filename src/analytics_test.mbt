///|
test "bloom filter estimates distinct items from occupancy" {
  let filter = @src.BloomFilter::with_size(8192, 5)
  assert_eq(filter.estimated_item_count(), 0.0)
  for i = 0; i < 100; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let estimate = filter.estimated_item_count()
  assert_true(estimate > 0.0)
  assert_true(estimate < 1000.0)
}

///|
test "counting filter estimates distinct items from occupancy" {
  let filter = @src.CountingBloomFilter::with_size(8192, 5)
  assert_eq(filter.estimated_item_count(), 0.0)
  for i = 0; i < 100; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let estimate = filter.estimated_item_count()
  assert_true(estimate > 0.0)
  assert_true(estimate < 1000.0)
}

///|
test "cuckoo filter reports capacity and false positive rate" {
  let filter = @src.CuckooFilter::with_size(2, 4)
  assert_eq(filter.capacity(), 8)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_true(filter.insert("a"))
  assert_true(filter.insert("b"))
  assert_eq(filter.load_factor(), 0.25)
  let rate = filter.false_positive_rate()
  assert_true(rate > 0.0 && rate < 0.05)
}

///|
test "concurrent wrappers expose analytics" {
  let bloom = @src.ConcurrentBloomFilter::with_size(1024, 4)
  bloom.insert("value")
  assert_true(bloom.estimated_item_count() > 0.0)
  let counting = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  counting.insert("value")
  assert_true(counting.estimated_item_count() > 0.0)
  let cuckoo = @src.ConcurrentCuckooFilter::with_size(2, 4)
  assert_eq(cuckoo.capacity(), 8)
  assert_true(cuckoo.insert("value"))
  assert_true(cuckoo.false_positive_rate() > 0.0)
}
