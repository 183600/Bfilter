///|
test "bloom filter reports set bits fill ratio and storage" {
  let filter = @src.BloomFilter::with_size(65, 4)
  assert_eq(filter.set_bit_count(), 0)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_eq(filter.memory_bytes(), 16L)
  filter.insert("value")
  let set_bits = filter.set_bit_count()
  assert_true(set_bits > 0)
  assert_true(set_bits <= filter.hash_count())
  assert_eq(filter.fill_ratio(), set_bits.to_double() / 128.0)
  filter.insert("value")
  assert_eq(filter.set_bit_count(), set_bits)
}

///|
test "counting filter reports occupied slots fill ratio and storage" {
  let filter = @src.CountingBloomFilter::with_size(17, 3)
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_eq(filter.memory_bytes(), 64L)
  filter.insert("value")
  let occupied = filter.occupied_slot_count()
  assert_true(occupied > 0)
  assert_true(occupied <= filter.hash_count())
  assert_eq(filter.fill_ratio(), occupied.to_double() / 32.0)
  filter.insert("value")
  assert_eq(filter.occupied_slot_count(), occupied)
  assert_true(filter.remove("value"))
  assert_true(filter.remove("value"))
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "cuckoo filter reports load factor and storage" {
  let filter = @src.CuckooFilter::with_size(1, 4)
  assert_eq(filter.load_factor(), 0.0)
  assert_eq(filter.memory_bytes(), 4L)
  assert_true(filter.insert("a"))
  assert_true(filter.insert("b"))
  assert_true(filter.insert("c"))
  assert_true(filter.insert("d"))
  assert_eq(filter.count(), 4)
  assert_eq(filter.load_factor(), 1.0)
  assert_true(filter.remove("a"))
  assert_eq(filter.load_factor(), 0.75)
}

///|
test "concurrent bloom filter reports occupancy statistics" {
  let filter = @src.ConcurrentBloomFilter::with_size(256, 4)
  assert_eq(filter.set_bit_count(), 0)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_eq(filter.memory_bytes(), 32L)
  filter.insert("value")
  assert_true(filter.set_bit_count() > 0)
  assert_true(filter.fill_ratio() > 0.0)
}

///|
test "concurrent counting filter reports occupancy statistics" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_eq(filter.memory_bytes(), 512L)
  filter.insert("value")
  assert_true(filter.occupied_slot_count() > 0)
  assert_true(filter.fill_ratio() > 0.0)
}

///|
test "concurrent cuckoo filter reports occupancy statistics" {
  let filter = @src.ConcurrentCuckooFilter::with_size(1, 4)
  assert_eq(filter.load_factor(), 0.0)
  assert_eq(filter.memory_bytes(), 4L)
  assert_true(filter.insert("a"))
  assert_eq(filter.load_factor(), 0.25)
}
