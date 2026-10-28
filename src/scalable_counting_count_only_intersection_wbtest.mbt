///|
fn count_only_scalable_for_intersection(
  count : Int32,
  slice_count : Int32,
) -> ScalableCountingBloomFilter {
  let filter = ScalableCountingBloomFilter::new(2, 0.01)
  while filter.slice_count() < slice_count {
    filter.append_slice()
  }
  filter.slices[filter.slice_count() - 1].inserted = count
  filter.inserted = count
  ScalableCountingBloomFilter::from_bytes(filter.to_bytes())
}

///|
test "scalable counting count-only intersections keep the smaller count" {
  let counted = count_only_scalable_for_intersection(5, 1)
  assert_eq(counted.tracked_key_count(), 0)
  assert_eq(counted.occupied_slot_count(), 0L)
  let other = ScalableCountingBloomFilter::new(2, 0.01)
  other.insert_all(["a", "b", "c"])
  let forward = counted.intersection(other)
  let backward = other.intersection(counted)
  for common in [forward, backward] {
    assert_eq(common.count(), 3)
    assert_eq(common.tracked_key_count(), 0)
    assert_eq(common.occupied_slot_count(), 0L)
    let restored = ScalableCountingBloomFilter::from_bytes(
      common.to_bytes(),
    )
    assert_eq(restored.count(), 3)
    assert_eq(restored.to_bytes(), common.to_bytes())
  }
}

///|
test "scalable counting count-only intersections keep the shorter layout" {
  let left = count_only_scalable_for_intersection(5, 3)
  let right = count_only_scalable_for_intersection(2, 2)
  let common = left.intersection(right)
  assert_eq(common.slice_count(), 2)
  assert_eq(common.count(), 2)
  assert_eq(common.tracked_key_count(), 0)
  assert_eq(common.occupied_slot_count(), 0L)
  let restored = ScalableCountingBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.count(), 2)
  assert_eq(restored.slice_count(), 2)
  assert_eq(restored.to_bytes(), common.to_bytes())
}
