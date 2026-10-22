///|
test "counting multiplicity raise advances every selected lane together" {
  // 2049 probes over sixteen slots select one slot 129 times and the other
  // fifteen slots 128 times. Their counter caps allow 508 and 511 complete
  // contributions respectively. Raising 600 contributions at once must stop at
  // the smaller count in every lane; advancing lanes independently would leave
  // a residue that no later removal of the key can drain.
  let filter = CountingBloomFilter::with_size(16, 2049)
  let key = "multiplicity"
  let (h1, h2) = key_hashes(key)
  let positions = unique_key_positions_fast(
    h1,
    h2,
    filter.hash_count,
    filter.slot_count.to_uint64(),
  )
  filter.raise_positions_at(positions, 600)
  filter.inserted = 508

  let mut minimum_counter = 65535UL
  for i = 0; i < positions.length; i = i + 1 {
    let value = filter.counter_at(positions.positions[i])
    if value < minimum_counter {
      minimum_counter = value
    }
  }
  assert_eq(minimum_counter, 65024UL)
  assert_eq(filter.count_of(key), 508)
  for i = 0; i < 508; i = i + 1 {
    assert_true(filter.remove(key))
  }
  assert_eq(filter.count_of(key), 0)
  assert_false(filter.contains(key))
  assert_eq(filter.occupied_slot_count(), 0)
  assert_false(filter.remove(key))
}
