///|
/// After `clear`, a scalable filter returns to a single slice with the original
/// initial capacity. Inserting enough keys again must trigger slice growth just
/// like a fresh filter, proving `clear` fully resets the growth state.
test "scalable bloom filter regrows slices after clear" {
  let filter = @src.ScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 0)
  assert_eq(filter.capacity(), 4L)
  assert_false(filter.contains("key-0"))
  assert_false(filter.contains("key-39"))
  // Re-insert enough keys to exceed the initial slice capacity and force growth.
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  assert_eq(filter.count(), 40)
  for i = 0; i < 40; i = i + 1 {
    assert_true(filter.contains("key-" + i.to_string()))
  }
}

///|
/// `clear` on a scalable counting filter empties the tracked-key metadata and
/// resets to a single slice. Re-inserting enough keys must trigger growth and
/// restore tracked multiplicities.
test "scalable counting filter regrows slices after clear" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key-0")
  filter.insert("key-0")
  filter.insert("key-1")
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  assert_eq(filter.count_of("key-0"), 3)
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 0)
  assert_eq(filter.tracked_key_count(), 0)
  assert_eq(filter.capacity(), 4L)
  assert_eq(filter.count_of("key-0"), 0)
  assert_false(filter.contains("key-0"))
  // Re-insert enough keys to exceed the initial slice capacity and force growth.
  // The loop re-inserts "key-0" once, then two more copies are added below, so
  // its tracked multiplicity is 3.
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  filter.insert("key-0")
  filter.insert("key-0")
  assert_true(filter.slice_count() > 1)
  assert_eq(filter.count(), 42)
  assert_eq(filter.count_of("key-0"), 3)
  assert_eq(filter.count_of("key-1"), 1)
  for i = 0; i < 40; i = i + 1 {
    assert_true(filter.contains("key-" + i.to_string()))
  }
}

///|
/// `clear` on an already-empty scalable filter is a no-op that preserves the
/// single-slice state and still allows subsequent growth.
test "scalable bloom filter clear on empty filter preserves growth policy" {
  let filter = @src.ScalableBloomFilter::new(4, 0.01)
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.capacity(), 4L)
  assert_true(filter.is_empty())
  assert_true(filter.insert_if_absent("fresh"))
  assert_true(filter.contains("fresh"))
}

///|
/// `clear` on a scalable counting filter that never grew still resets counters
/// and tracked metadata without allocating new storage.
test "scalable counting filter clear on empty filter preserves growth policy" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key-0")
  assert_true(filter.remove("key-0"))
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.capacity(), 4L)
  assert_eq(filter.tracked_key_count(), 0)
  assert_true(filter.is_empty())
  assert_true(filter.insert_if_absent("fresh"))
  assert_eq(filter.count_of("fresh"), 1)
  assert_true(filter.remove("fresh"))
  assert_eq(filter.count_of("fresh"), 0)
}
