///|
test "blocked bloom empty filter misses without probing" {
  let filter = @src.BlockedBloomFilter::with_size(512, 1_000_000)
  assert_eq(filter.count(), 0)
  assert_eq(filter.set_bit_count(), 0)
  assert_false(filter.contains("absent"))
  assert_false(filter.contains_all(["absent", "missing"]))
  assert_false(filter.contains_any(["absent", "missing"]))
}
