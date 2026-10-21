///|
test "scalable counting insert_if_absent keeps saturated tracked keys absent" {
  let filter = @src.ScalableCountingBloomFilter::new(65536, 0.5)
  for i = 0; i < 65536; i = i + 1 {
    filter.insert("saturated")
  }
  for i = 0; i < 65535; i = i + 1 {
    assert_true(filter.remove("saturated"))
  }
  assert_false(filter.contains("saturated"))
  assert_eq(filter.count_of("saturated"), 1)
  assert_eq(filter.count(), 1)
  assert_eq(filter.tracked_key_count(), 1)
  assert_false(filter.insert_if_absent("saturated"))
  assert_eq(filter.count_of("saturated"), 1)
  assert_eq(filter.count(), 1)
  assert_eq(filter.tracked_key_count(), 1)
  assert_true(filter.insert_if_absent("fresh"))
  assert_eq(filter.count_of("fresh"), 1)
  assert_eq(filter.count(), 2)
  let restored = @src.ScalableCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_false(restored.insert_if_absent("saturated"))
  assert_eq(restored.count_of("saturated"), 1)
  assert_true(restored.insert_if_absent("another"))
  assert_eq(restored.count_of("another"), 1)
}
