///|
test "scalable counting union keeps drained tracked keys absent" {
  let drained = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 65536; i = i + 1 {
    drained.insert("hot")
  }
  for i = 0; i < 65535; i = i + 1 {
    assert_true(drained.remove("hot"))
  }
  assert_false(drained.contains("hot"))
  assert_eq(drained.count_of("hot"), 1)
  assert_eq(drained.count(), 1)

  let self_union = drained.union(drained)
  assert_false(self_union.contains("hot"))
  assert_eq(self_union.count_of("hot"), 1)
  assert_eq(self_union.count(), 1)
  assert_false(self_union.remove("hot"))

  let other = @src.ScalableCountingBloomFilter::new(1, 0.5)
  other.insert("cold")
  let combined = drained.union(other)
  assert_false(combined.contains("hot"))
  assert_eq(combined.count_of("hot"), 1)
  assert_true(combined.contains("cold"))
  assert_eq(combined.count_of("cold"), 1)
  assert_eq(combined.count(), 2)

  let merged = drained.copy()
  merged.merge(other)
  assert_eq(merged.to_bytes(), combined.to_bytes())
  assert_false(merged.contains("hot"))
  assert_eq(merged.count_of("hot"), 1)

  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_eq(restored.to_bytes(), combined.to_bytes())
  assert_false(restored.contains("hot"))
  assert_eq(restored.count_of("hot"), 1)
  assert_true(restored.contains("cold"))

  assert_true(combined.remove("cold"))
  assert_false(combined.remove("hot"))
  assert_eq(combined.count_of("hot"), 1)
  assert_eq(combined.count(), 1)
  let restored_after = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_eq(restored_after.to_bytes(), combined.to_bytes())
  assert_false(restored_after.contains("hot"))
  assert_eq(restored_after.count_of("hot"), 1)
}
