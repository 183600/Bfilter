///|
test "counting bloom remove tolerates duplicate hash positions" {
  let filter = @src.CountingBloomFilter::with_size(48, 32)
  for key = 0; key < 100; key = key + 1 {
    filter.insert("dup-\{key}")
  }
  for key = 0; key < 100; key = key + 1 {
    assert_true(filter.remove("dup-\{key}"))
  }
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "compact counting remove tolerates duplicate hash positions" {
  let filter = @src.CompactCountingBloomFilter::with_size(96, 97)
  let keys = ["a", "b", "c"]
  for key in keys {
    filter.insert(key)
  }
  for key in keys {
    assert_true(filter.remove(key))
  }
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "compact counting repeated removals do not corrupt counters" {
  let filter = @src.CompactCountingBloomFilter::new(1000, 0.01)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("saturated")
  }
  assert_eq(filter.count_of("saturated"), 15)
  assert_true(filter.remove("saturated"))
  assert_eq(filter.count_of("saturated"), 14)
  assert_true(filter.occupied_slot_count() > 0)
}
