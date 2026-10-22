///|
test "full blocked bloom filter short-circuits a wide block walk" {
  let source = @src.BlockedBloomFilter::with_size(1024, 1)
  let mut index = 0
  while source.set_bit_count() < source.bit_count() && index < 100_000 {
    source.insert("fill-" + index.to_string())
    index = index + 1
  }
  assert_eq(source.set_bit_count(), source.bit_count())
  assert_eq(source.block_count(), 2)

  // Keep every bit set but give the filter a maximal hash count. The effective
  // block walk is one 512-probe cycle, so the full-filter scan is what keeps
  // these operations cheap.
  let bytes = source.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 2147483647U)
  let full = @src.BlockedBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  assert_eq(full.hash_count(), 2147483647)
  assert_eq(full.set_bit_count(), full.bit_count())
  assert_true(full.contains("anything"))
  assert_false(full.insert_if_absent("anything"))
  let before = full.count()
  full.insert("anything")
  assert_eq(full.count(), before + 1)
  assert_eq(full.insert_all_if_absent(["a", "b"]), 0)
  assert_eq(full.count(), before + 1)
  assert_true(full.contains_all(["a", "b"]))

  let restored = @src.BlockedBloomFilter::from_bytes(full.to_bytes())
  assert_eq(restored.count(), full.count())
  assert_eq(restored.set_bit_count(), restored.bit_count())
  assert_true(restored.contains("anything"))
}
