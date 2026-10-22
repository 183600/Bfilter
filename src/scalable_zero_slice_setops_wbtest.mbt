///|
fn zero_slice_bloom_for_setops() -> ScalableBloomFilter {
  {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
}

///|
fn zero_slice_counting_for_setops() -> ScalableCountingBloomFilter {
  {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
}

///|
test "zero-slice scalable bloom merges and unions become serializable" {
  let left = zero_slice_bloom_for_setops()
  let right = zero_slice_bloom_for_setops()
  let union = left.union(right)
  assert_eq(union.slice_count(), 1)
  assert_eq(union.count(), 0)
  let restored = ScalableBloomFilter::from_bytes(union.to_bytes())
  assert_eq(restored.to_bytes(), union.to_bytes())

  let merged = left.copy()
  merged.merge(right)
  assert_eq(merged.to_bytes(), union.to_bytes())
  assert_eq(ScalableBloomFilter::from_bytes(merged.to_bytes()).count(), 0)
  assert_true(merged.insert_if_absent("after"))
  assert_true(merged.contains("after"))
}

///|
test "zero-slice scalable counting merges and unions become serializable" {
  let left = zero_slice_counting_for_setops()
  let right = zero_slice_counting_for_setops()
  let union = left.union(right)
  assert_eq(union.slice_count(), 1)
  assert_eq(union.count(), 0)
  let restored = ScalableCountingBloomFilter::from_bytes(union.to_bytes())
  assert_eq(restored.to_bytes(), union.to_bytes())

  let merged = left.copy()
  merged.merge(right)
  assert_eq(merged.to_bytes(), union.to_bytes())
  assert_eq(ScalableCountingBloomFilter::from_bytes(merged.to_bytes()).count(), 0)
  assert_true(merged.insert_if_absent("after"))
  assert_true(merged.contains("after"))
}
