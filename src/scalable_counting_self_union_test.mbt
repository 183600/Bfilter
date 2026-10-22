///|
test "scalable counting self union preserves tracked multiplicities" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("shared")
  filter.insert("shared")
  filter.insert("shared")
  filter.insert("single")
  for i = 0; i < 12; i = i + 1 {
    filter.insert("fill-" + i.to_string())
  }
  let combined = filter.union(filter)
  assert_eq(combined.count(), filter.count())
  assert_eq(combined.tracked_key_count(), filter.tracked_key_count())
  assert_eq(combined.count_of("shared"), 3)
  assert_eq(combined.count_of("single"), 1)
  let merged = filter.copy()
  merged.merge(filter)
  assert_eq(merged.count(), filter.count())
  assert_eq(merged.count_of("shared"), 3)
  assert_eq(merged.tracked_key_count(), filter.tracked_key_count())
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_eq(restored.count_of("shared"), 3)
  assert_true(restored.remove("shared"))
  assert_eq(restored.count_of("shared"), 2)
  assert_eq(filter.count_of("shared"), 3)
}
