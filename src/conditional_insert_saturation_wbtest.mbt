///|
test "conditional insertion raises the remaining lanes beside a saturated repeat" {
  let filter = CountingBloomFilter::with_size(16, 17)
  let key = "conditional-ceiling"
  let (h1, h2) = key_hashes(key)
  let positions = unique_key_positions(
    h1,
    h2,
    filter.hash_count,
    filter.slot_count.to_uint64(),
  )
  let mut repeated = -1
  let mut occurrences = 0UL
  for entry in positions {
    if repeated < 0 && entry.1 >= 2 {
      repeated = entry.0
      occurrences = entry.1.to_uint64()
    }
  }
  assert_true(repeated >= 0)
  // A repeated lane above its removable ceiling cannot accept another complete
  // contribution, so the conditional insertion must raise the other zero lanes
  // instead of leaving the key half-present.
  filter.set_counter(repeated, 0xFFFFUL)
  assert_true(filter.insert_if_absent(key))
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of(key), 1)
  assert_true(filter.contains(key))
  assert_eq(filter.counter_at(repeated), 0xFFFFUL)
  assert_true(filter.remove(key))
  assert_eq(filter.count_of(key), 0)
  assert_false(filter.contains(key))
  assert_eq(filter.counter_at(repeated), 0xFFFFUL - occurrences)
}

///|
test "compact conditional insertion raises the remaining lanes beside a saturated repeat" {
  let filter = CompactCountingBloomFilter::with_size(16, 17)
  let key = "compact-conditional-ceiling"
  let (h1, h2) = key_hashes(key)
  let positions = unique_key_positions(
    h1,
    h2,
    filter.hash_count,
    filter.slot_count.to_uint64(),
  )
  let mut repeated = -1
  let mut occurrences = 0UL
  for entry in positions {
    if repeated < 0 && entry.1 >= 2 {
      repeated = entry.0
      occurrences = entry.1.to_uint64()
    }
  }
  assert_true(repeated >= 0)
  filter.set_counter(repeated, COMPACT_COUNTER_MAX)
  assert_true(filter.insert_if_absent(key))
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of(key), 1)
  assert_true(filter.contains(key))
  assert_eq(filter.counter_at(repeated), COMPACT_COUNTER_MAX)
  assert_true(filter.remove(key))
  assert_eq(filter.count_of(key), 0)
  assert_false(filter.contains(key))
  assert_eq(filter.counter_at(repeated), COMPACT_COUNTER_MAX - occurrences)
}

///|
test "panic counting conditional insertion rejects count overflow on a zero lane" {
  let bytes = CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  let filter = CountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  filter.insert_if_absent("overflow") |> ignore
}
