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
