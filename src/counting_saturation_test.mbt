///|
test "counting saturation shared keys" {
  let filter = @src.CountingBloomFilter::with_size(16, 70000)
  filter.insert("left")
  filter.insert("right")
  assert_true(filter.contains("left"))
  assert_true(filter.contains("right"))
  assert_true(filter.remove("left"))
  assert_true(filter.contains("right"))
}

///|
test "saturation compact serialization after false positive removal" {
  let filter = @src.CompactCountingBloomFilter::with_size(48, 720)
  filter.insert(96)
  assert_true(filter.remove(251))
  assert_true(filter.count() > 0)
  let restored = @src.CompactCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
  assert_true(restored.contains(96) == filter.contains(96))
}

///|
test "counting bloom filter remove with saturated counters" {
  let filter = @src.CountingBloomFilter::new(10, 0.01)
  // Insert a key many times to saturate counters
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("key")
  }
  let count_after_inserts = filter.count()
  
  // Remove once
  assert_true(filter.remove("key"))
  let count_after_remove = filter.count()
  
  // The count should decrease by 1, not increase
  assert_eq(count_after_remove, count_after_inserts - 1)
}
