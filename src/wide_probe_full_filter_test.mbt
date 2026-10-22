///|
test "full non-power-of-two bloom filter short-circuits a wide probe walk" {
  // Fill every bit with a cheap one-hash layout, then serialize the state with
  // a maximal hash count. Without the full-filter shortcut, each query would
  // walk the nominal 2^31-1 probes even though no bit can change.
  let source = @src.BloomFilter::with_size(192, 1)
  let mut index = 0
  while source.set_bit_count() < source.bit_count() && index < 100_000 {
    source.insert("fill-" + index.to_string())
    index = index + 1
  }
  assert_eq(source.set_bit_count(), source.bit_count())
  assert_eq(source.bit_count(), 192)

  let bytes = source.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 2147483647U)
  let full = @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  assert_eq(full.hash_count(), 2147483647)
  assert_eq(full.set_bit_count(), full.bit_count())
  assert_true(full.contains("anything"))
  assert_false(full.insert_if_absent("anything"))
  let before = full.count()
  full.insert("anything")
  assert_eq(full.count(), before + 1)
  assert_eq(full.insert_all_if_absent(["a", "b", "c"]), 0)
  assert_eq(full.count(), before + 1)
  assert_true(full.contains_all(["a", "b", "c"]))

  let restored = @src.BloomFilter::from_bytes(full.to_bytes())
  assert_eq(restored.count(), full.count())
  assert_eq(restored.set_bit_count(), restored.bit_count())
  assert_true(restored.contains("anything"))
}
