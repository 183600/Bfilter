///|
test "scalable counting saturated cross-slice merges stay serializable" {
  let left = @src.ScalableCountingBloomFilter::new(1, 0.01)
  let right = @src.ScalableCountingBloomFilter::new(1, 0.01)
  for i = 0; i < 70000; i = i + 1 {
    left.insert("shared")
  }
  for i = 0; i < 5; i = i + 1 {
    right.insert("other-" + i.to_string())
  }
  for i = 0; i < 70000; i = i + 1 {
    right.insert("shared")
  }
  assert_true(right.slice_count() > left.slice_count())
  let merged = left.union(right)
  assert_eq(merged.count_of("shared"), 140000)
  assert_eq(merged.count(), 140005)
  let restored = @src.ScalableCountingBloomFilter::from_bytes(merged.to_bytes())
  assert_eq(restored.count_of("shared"), 140000)
  assert_eq(restored.count(), 140005)
  assert_true(restored.remove("shared"))
  assert_eq(restored.count_of("shared"), 139999)
  assert_eq(restored.count(), 140004)
  let round_trip = @src.ScalableCountingBloomFilter::from_bytes(
    restored.to_bytes(),
  )
  assert_eq(round_trip.count_of("shared"), 139999)
  assert_eq(round_trip.count(), 140004)
}
