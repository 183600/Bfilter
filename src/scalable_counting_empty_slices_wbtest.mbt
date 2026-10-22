///|
test "scalable counting intersection handles a filter with no slices" {
  let empty : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
  let other = ScalableCountingBloomFilter::new(2, 0.01)
  other.insert("present")

  let forward = empty.intersection(other)
  assert_eq(forward.count(), 0)
  assert_eq(forward.slice_count(), 1)
  assert_true(forward.is_empty())
  assert_true(forward.insert_if_absent("fresh"))
  assert_eq(forward.count_of("fresh"), 1)
  assert_true(forward.remove("fresh"))

  let backward = other.intersection(empty)
  assert_eq(backward.count(), 0)
  assert_eq(backward.slice_count(), 1)
  assert_true(backward.is_empty())
  assert_true(backward.insert_if_absent("fresh"))
  assert_eq(backward.count_of("fresh"), 1)
  assert_true(backward.remove("fresh"))
}

///|
test "scalable counting statistics handle a filter with no slices" {
  let empty : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
  assert_eq(empty.slice_count(), 0)
  assert_eq(empty.capacity(), 0L)
  assert_eq(empty.slot_count(), 0L)
  assert_eq(empty.occupied_slot_count(), 0L)
  assert_eq(empty.fill_ratio(), 0.0)
  assert_eq(empty.estimated_item_count(), 0.0)
  assert_eq(empty.false_positive_rate(), 0.0)
  assert_eq(empty.memory_bytes(), 0L)
  assert_eq(empty.tracked_key_count(), 0)
  assert_true(empty.is_empty())
  assert_true(
    empty.is_subset_of(ScalableCountingBloomFilter::new(2, 0.01)),
  )
  assert_true(
    empty.is_disjoint_from(ScalableCountingBloomFilter::new(2, 0.01)),
  )
}
