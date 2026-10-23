///|
test "clearing zero-slice scalable filters restarts from one empty slice" {
  let bloom : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 8,
    target_rate: 0.01,
    inserted: 5,
  }
  bloom.clear()
  assert_eq(bloom.slice_count(), 1)
  assert_eq(bloom.count(), 0)
  assert_eq(bloom.capacity(), 8L)
  assert_eq(bloom.target_false_positive_rate(), 0.01)
  assert_true(bloom.is_empty())
  assert_false(bloom.contains("missing"))
  let bloom_restored = ScalableBloomFilter::from_bytes(bloom.to_bytes())
  assert_eq(bloom_restored.slice_count(), 1)
  assert_eq(bloom_restored.count(), 0)

  let counting : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: 8,
    target_rate: 0.01,
    inserted: 5,
  }
  counting.clear()
  assert_eq(counting.slice_count(), 1)
  assert_eq(counting.count(), 0)
  assert_eq(counting.capacity(), 8L)
  assert_eq(counting.target_false_positive_rate(), 0.01)
  assert_true(counting.is_empty())
  assert_false(counting.contains("missing"))
  assert_eq(counting.count_of("missing"), 0)
  let counting_restored = ScalableCountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_eq(counting_restored.slice_count(), 1)
  assert_eq(counting_restored.count(), 0)
}
