///|
test "merging an empty scalable bloom filter preserves exact state" {
  let filter = @src.ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  let before = filter.to_bytes()
  let count = filter.count()
  let slice_count = filter.slice_count()
  let empty = @src.ScalableBloomFilter::new(2, 0.01)
  filter.merge(empty)
  assert_eq(filter.to_bytes(), before)
  assert_eq(filter.count(), count)
  assert_eq(filter.slice_count(), slice_count)
  assert_true(filter.contains("key-39"))
}

///|
test "merging an empty scalable counting filter preserves exact state" {
  let filter = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 70_000; i = i + 1 {
    filter.insert("hot")
  }
  filter.insert("cold")
  let before = filter.to_bytes()
  let count = filter.count()
  let slice_count = filter.slice_count()
  let tracked = filter.tracked_key_count()
  let empty = @src.ScalableCountingBloomFilter::new(1, 0.5)
  filter.merge(empty)
  assert_eq(filter.to_bytes(), before)
  assert_eq(filter.count(), count)
  assert_eq(filter.slice_count(), slice_count)
  assert_eq(filter.tracked_key_count(), tracked)
  assert_eq(filter.count_of("hot"), 70_000)
  assert_eq(filter.count_of("cold"), 1)
}

///|
test "concurrent scalable wrappers keep their receiver when merging an empty filter" {
  let bloom = @src.ConcurrentScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    bloom.insert(i)
  }
  let bloom_before = bloom.to_bytes()
  bloom.merge(@src.ScalableBloomFilter::new(2, 0.01))
  assert_eq(bloom.to_bytes(), bloom_before)

  let counting = @src.ConcurrentScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 20; i = i + 1 {
    counting.insert(i)
  }
  let counting_before = counting.to_bytes()
  counting.merge(@src.ScalableCountingBloomFilter::new(1, 0.5))
  assert_eq(counting.to_bytes(), counting_before)
}
