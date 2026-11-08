test "drained tracked keys stay absent after a union" {
  let drained = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 65536; i = i + 1 {
    drained.insert("hot")
  }
  for i = 0; i < 65535; i = i + 1 {
    assert_true(drained.remove("hot"))
  }
  assert_false(drained.contains("hot"))
  assert_eq(drained.count_of("hot"), 1)
  let other = @src.ScalableCountingBloomFilter::new(1, 0.5)
  other.insert("cold")
  let combined = drained.union(other)
  assert_false(combined.contains("hot"))
  assert_eq(combined.count_of("hot"), 1)
  assert_eq(combined.count(), 2)
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_false(restored.contains("hot"))
  let merged = drained.copy()
  merged.merge(other)
  assert_false(merged.contains("hot"))
}
