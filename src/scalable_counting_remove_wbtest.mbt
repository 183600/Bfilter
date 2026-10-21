///|
test "scalable counting remove never falls back to another slice" {
  let filter = ScalableCountingBloomFilter::new(4, 0.7)
  let key = "probe-owner"
  let (h1, h2) = key_hashes(key)
  let owned = filter.slices[0]
  let owned_positions = unique_key_positions(
    h1,
    h2,
    owned.hash_count,
    owned.slot_count.to_uint64(),
  )
  for entry in owned_positions {
    owned.set_counter(entry.0, 0UL)
  }
  filter.locations.set((h1, h2), (0, 1))
  filter.inserted = 1
  filter.append_slice()
  let other = filter.slices[1]
  let other_positions = unique_key_positions(
    h1,
    h2,
    other.hash_count,
    other.slot_count.to_uint64(),
  )
  for entry in other_positions {
    other.set_counter(entry.0, entry.1.to_uint64())
  }
  let before = other.to_bytes()
  assert_false(filter.remove(key))
  assert_eq(other.to_bytes(), before)
  assert_eq(filter.count_of(key), 1)
}
