///|
test "scalable counting intersection survives serialization when slots collide" {
  let left = @src.ScalableCountingBloomFilter::new(30, 0.2)
  let right = @src.ScalableCountingBloomFilter::new(30, 0.2)
  left.insert("shared")
  right.insert("shared")
  for i = 0; i < 25; i = i + 1 {
    left.insert("left-" + i.to_string())
    right.insert("right-" + i.to_string())
  }
  assert_eq(left.slice_count(), 1)
  assert_eq(right.slice_count(), 1)
  let common = left.intersection(right)
  assert_true(common.contains("shared"))
  let restored = @src.ScalableCountingBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.count(), common.count())
  assert_true(restored.contains("shared"))
}
