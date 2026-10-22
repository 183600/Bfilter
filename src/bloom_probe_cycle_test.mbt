///|
test "bloom filters handle hash counts wider than their bit array" {
  // A 64-bit filter has one full double-hash cycle after 64 probes. The
  // remaining (ten million) hash functions cannot set or test a new bit.
  let filter = @src.BloomFilter::with_size(64, 10_000_000)
  filter.insert("wide")
  assert_eq(filter.hash_count(), 10_000_000)
  assert_eq(filter.count(), 1)
  assert_eq(filter.set_bit_count(), filter.bit_count())
  assert_true(filter.contains("wide"))
  assert_false(filter.insert_if_absent("wide"))
  assert_eq(filter.count(), 1)
  let restored = @src.BloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.contains("wide"))
  assert_eq(restored.set_bit_count(), restored.bit_count())
}

///|
test "blocked filters handle hash counts wider than one block" {
  // Every probe is confined to a 512-bit block, so a wider hash count repeats
  // offsets after one cycle instead of rescanning the same block.
  let filter = @src.BlockedBloomFilter::with_size(1024, 10_000_000)
  filter.insert("wide")
  assert_eq(filter.hash_count(), 10_000_000)
  assert_eq(filter.count(), 1)
  assert_eq(filter.set_bit_count(), 512)
  assert_true(filter.contains("wide"))
  assert_false(filter.insert_if_absent("wide"))
  assert_eq(filter.count(), 1)
  let restored = @src.BlockedBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.contains("wide"))
  assert_eq(restored.set_bit_count(), 512)
}
