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
test "merging an empty grown scalable counting filter preserves saturated counters" {
  let filter = @src.ScalableCountingBloomFilter::new(1, 0.01)
  for i = 0; i < 70_000; i = i + 1 {
    filter.insert("hot")
  }
  for i = 0; i < 65_535; i = i + 1 {
    assert_true(filter.remove("hot"))
  }
  assert_false(filter.contains("hot"))
  assert_eq(filter.count_of("hot"), 4_465)
  let count = filter.count()
  let tracked = filter.tracked_key_count()
  let slice_count = filter.slice_count()
  let occupied = filter.occupied_slot_count()

  let empty = @src.ScalableCountingBloomFilter::new(1, 0.01)
  for i = 0; i < 3; i = i + 1 {
    empty.insert("grow-" + i.to_string())
  }
  assert_true(empty.slice_count() > slice_count)
  for i = 0; i < 3; i = i + 1 {
    assert_true(empty.remove("grow-" + i.to_string()))
  }
  assert_true(empty.is_empty())
  assert_eq(empty.tracked_key_count(), 0)
  let empty_slices = empty.slice_count()

  filter.merge(empty)
  assert_eq(filter.slice_count(), empty_slices)
  assert_eq(filter.count(), count)
  assert_eq(filter.tracked_key_count(), tracked)
  assert_eq(filter.occupied_slot_count(), occupied)
  assert_false(filter.contains("hot"))
  assert_eq(filter.count_of("hot"), 4_465)
  assert_false(filter.remove("hot"))
  assert_false(filter.insert_if_absent("hot"))
  assert_eq(filter.count_of("hot"), 4_465)

  assert_true(filter.insert_if_absent("fresh"))
  assert_eq(filter.count_of("fresh"), 1)
  assert_true(filter.contains("fresh"))
  let restored = @src.ScalableCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.tracked_key_count(), filter.tracked_key_count())
  assert_false(restored.contains("hot"))
  assert_eq(restored.count_of("hot"), 4_465)
  assert_true(restored.contains("fresh"))
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
