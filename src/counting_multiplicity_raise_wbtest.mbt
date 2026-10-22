///|
test "counting multiplicity raise advances every selected lane together" {
  // Seventeen probes over sixteen slots select one slot twice and the rest
  // once.  Raising seven complete contributions at once must cap the duplicate
  // lane at fourteen and the other lanes at seven, not at their independent
  // limits, so exactly seven removals drain every selected counter.
  let filter = CountingBloomFilter::with_size(16, 17)
  let key = "multiplicity"
  let (h1, h2) = key_hashes(key)
  let positions = unique_key_positions_fast(
    h1,
    h2,
    filter.hash_count,
    filter.slot_count.to_uint64(),
  )
  filter.raise_positions_at(positions, 7)
  filter.inserted = 7

  assert_eq(filter.count_of(key), 7)
  for i = 0; i < 7; i = i + 1 {
    assert_true(filter.remove(key))
  }
  assert_eq(filter.count_of(key), 0)
  assert_false(filter.contains(key))
  assert_eq(filter.occupied_slot_count(), 0)
  assert_false(filter.remove(key))
}
