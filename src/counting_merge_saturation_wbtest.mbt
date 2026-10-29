///|
test "counting merge leaves a saturated repeated position unchanged" {
  let filter = CountingBloomFilter::with_size(16, 65)
  let (h1, h2) = key_hashes("saturated")
  let positions = filter.positions_for(h1, h2)
  assert_eq(positions.length, 16)
  let mut saturated = -1
  for i = 0; i < positions.length; i = i + 1 {
    if positions.counts[i] == 4 {
      saturated = i
      break
    }
  }
  assert_true(saturated >= 0)
  let position = positions.positions[saturated]
  filter.set_counter(position, 65535UL)
  filter.raise_positions_for_new_merge(h1, h2, 1)
  assert_eq(filter.counter_at(position), 65535UL)
}
