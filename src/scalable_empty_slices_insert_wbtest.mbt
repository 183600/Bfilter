///|
test "scalable bloom filter with no slices accepts insertion" {
  let filter : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
  filter.insert("first")
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("first"))
  filter.insert("second")
  assert_eq(filter.count(), 2)
  assert_true(filter.contains_all(["first", "second"]))

  let restored = ScalableBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.slice_count(), filter.slice_count())
  assert_eq(restored.count(), filter.count())
  assert_true(restored.contains_all(["first", "second"]))
}

///|
test "scalable counting filter with no slices accepts insertion and removal" {
  let filter : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
  assert_true(filter.insert_if_absent("first"))
  assert_false(filter.insert_if_absent("first"))
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of("first"), 1)
  assert_true(filter.contains("first"))

  let restored = ScalableCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.slice_count(), filter.slice_count())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.count_of("first"), 1)
  assert_true(restored.remove("first"))
  assert_eq(restored.count_of("first"), 0)
  assert_false(restored.contains("first"))
}
