///|
test "counting filters insert and remove with a very wide hash count" {
  let counting = @src.CountingBloomFilter::with_size(16, 10_000_000)
  counting.insert(3)
  assert_true(counting.contains(3))
  assert_eq(counting.count_of(3), @src.CountingBloomFilter::counter_max())
  let restored_counting = @src.CountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_eq(restored_counting.count_of(3), counting.count_of(3))
  assert_true(restored_counting.remove(3))
  assert_eq(restored_counting.count(), 0)
  assert_false(restored_counting.contains(3))

  let compact = @src.CompactCountingBloomFilter::with_size(16, 10_000_000)
  compact.insert(3)
  assert_true(compact.contains(3))
  assert_eq(
    compact.count_of(3),
    @src.CompactCountingBloomFilter::counter_max(),
  )
  let restored_compact = @src.CompactCountingBloomFilter::from_bytes(
    compact.to_bytes(),
  )
  assert_eq(restored_compact.count_of(3), compact.count_of(3))
  assert_true(restored_compact.remove(3))
  assert_eq(restored_compact.count(), 0)
  assert_false(restored_compact.contains(3))
}

///|
test "counting conditional insertion handles a very wide hash count" {
  let filter = @src.CountingBloomFilter::with_size(16, 10_000_000)
  assert_true(filter.insert_if_absent("wide"))
  assert_false(filter.insert_if_absent("wide"))
  assert_eq(filter.count(), 1)
  // Every slot is saturated by the first key, so another key is a false
  // positive and must not be added.
  assert_eq(filter.insert_all_if_absent(["wide", "other"]), 0)
  assert_eq(filter.count(), 1)
  assert_true(filter.remove("wide"))
  assert_eq(filter.count(), 0)

  let compact = @src.CompactCountingBloomFilter::with_size(16, 10_000_000)
  assert_true(compact.insert_if_absent("wide"))
  assert_false(compact.insert_if_absent("wide"))
  assert_eq(compact.count(), 1)
  assert_eq(compact.insert_all_if_absent(["wide", "other"]), 0)
  assert_eq(compact.count(), 1)
  assert_true(compact.remove("wide"))
  assert_eq(compact.count(), 0)
}
