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

///|
test "zero-slice scalable bloom preserves conservative counts across inserts and merges" {
  let left : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  let right : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 3,
  }
  let union = left.union(right)
  assert_eq(union.count(), 8)
  assert_eq(union.slice_count(), 1)
  let restored = ScalableBloomFilter::from_bytes(union.to_bytes())
  assert_eq(restored.count(), 8)
  let merged = left.copy()
  merged.merge(right)
  assert_eq(merged.to_bytes(), union.to_bytes())

  let inserted = left.copy()
  inserted.insert("after")
  assert_eq(inserted.count(), 6)
  assert_true(inserted.contains("after"))
  let round_trip = ScalableBloomFilter::from_bytes(inserted.to_bytes())
  assert_eq(round_trip.count(), 6)
  assert_true(round_trip.contains("after"))
}

///|
test "zero-slice scalable counting preserves conservative counts across inserts and merges" {
  let left : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  let right : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 3,
  }
  let union = left.union(right)
  assert_eq(union.count(), 5)
  assert_eq(union.slice_count(), 1)
  let restored = ScalableCountingBloomFilter::from_bytes(union.to_bytes())
  assert_eq(restored.count(), 5)
  let merged = left.copy()
  merged.merge(right)
  assert_eq(merged.to_bytes(), union.to_bytes())

  let inserted = left.copy()
  inserted.insert("after")
  assert_eq(inserted.count(), 6)
  assert_eq(inserted.count_of("after"), 1)
  assert_true(inserted.contains("after"))
  let round_trip = ScalableCountingBloomFilter::from_bytes(inserted.to_bytes())
  assert_eq(round_trip.count(), 6)
  assert_eq(round_trip.count_of("after"), 1)
  assert_true(round_trip.contains("after"))
}

///|
test "zero-slice scalable bloom intersections keep conservative counts" {
  let counted : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  let empty = ScalableBloomFilter::new(2, 0.01)
  let forward = counted.intersection(empty)
  assert_eq(forward.slice_count(), 1)
  assert_eq(forward.count(), 0)
  let backward = empty.intersection(counted)
  assert_eq(backward.count(), 0)
  assert_eq(ScalableBloomFilter::from_bytes(forward.to_bytes()).count(), 0)

  let other : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 3,
  }
  let common = counted.intersection(other)
  assert_eq(common.slice_count(), 1)
  assert_eq(common.count(), 3)
  let restored = ScalableBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.count(), 3)
  assert_eq(restored.to_bytes(), common.to_bytes())
}

///|
test "zero-slice scalable bloom counts survive merges with sliced filters" {
  let counted : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  let sliced = ScalableBloomFilter::new(2, 0.01)
  sliced.insert("source")
  let forward = counted.union(sliced)
  assert_eq(forward.count(), 6)
  assert_true(forward.contains("source"))
  assert_eq(
    ScalableBloomFilter::from_bytes(forward.to_bytes()).count(),
    6,
  )
  let backward = sliced.union(counted)
  assert_eq(backward.count(), 6)
  assert_eq(
    ScalableBloomFilter::from_bytes(backward.to_bytes()).count(),
    6,
  )

  let merged = counted.copy()
  merged.merge(sliced)
  assert_eq(merged.to_bytes(), forward.to_bytes())
  let merged_back = sliced.copy()
  merged_back.merge(counted)
  assert_eq(merged_back.to_bytes(), backward.to_bytes())

  let grown_empty = ScalableBloomFilter::new(2, 0.01)
  grown_empty.insert("grow")
  grown_empty.clear()
  grown_empty.append_slice()
  let with_empty = counted.copy()
  with_empty.merge(grown_empty)
  assert_eq(with_empty.count(), 5)
  assert_eq(
    ScalableBloomFilter::from_bytes(with_empty.to_bytes()).count(),
    5,
  )
}
