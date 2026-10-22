///|
test "scalable bloom intersection handles a filter with no slices" {
  let empty : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
  let other = ScalableBloomFilter::new(2, 0.01)
  other.insert("present")

  let forward = empty.intersection(other)
  assert_eq(forward.count(), 0)
  assert_eq(forward.slice_count(), 1)
  assert_true(forward.is_empty())
  assert_false(forward.contains("present"))

  let backward = other.intersection(empty)
  assert_eq(backward.count(), 0)
  assert_eq(backward.slice_count(), 1)
  assert_true(backward.is_empty())
  assert_false(backward.contains("present"))
}

///|
test "scalable bloom statistics handle a filter with no slices" {
  let empty : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
  assert_eq(empty.slice_count(), 0)
  assert_eq(empty.capacity(), 0L)
  assert_eq(empty.bit_count(), 0)
  assert_eq(empty.set_bit_count(), 0)
  assert_eq(empty.fill_ratio(), 0.0)
  assert_eq(empty.estimated_item_count(), 0.0)
  assert_eq(empty.false_positive_rate(), 0.0)
  assert_eq(empty.memory_bytes(), 0L)
  assert_true(empty.is_empty())
  assert_true(empty.is_subset_of(ScalableBloomFilter::new(2, 0.01)))
  assert_true(empty.is_disjoint_from(ScalableBloomFilter::new(2, 0.01)))
}
