///|
fn wide_cycle_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
fn assert_cycle_matches_full_scan(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : Int32,
) -> Unit raise {
  let positions = FixedArray::make(slot_count, 0)
  let counts = FixedArray::make(slot_count, 0)
  let length = unique_key_positions_into(
    h1, h2, hash_count, slot_count.to_uint64(), positions, counts,
  )
  let expected : @hashmap.HashMap[Int32, Int32] = @hashmap.HashMap([])
  let mut state = h1
  for i = 0; i < hash_count; i = i + 1 {
    let position = (state % slot_count.to_uint64()).to_int()
    match expected.get(position) {
      Some(count) => expected.set(position, count + 1)
      None => expected.set(position, 1)
    }
    state = state + h2
  }
  assert_eq(length, expected.length())
  let mut total = 0
  for i = 0; i < length; i = i + 1 {
    let count = match expected.get(positions[i]) {
      Some(count) => count
      None => 0
    }
    assert_eq(counts[i], count)
    total = total + count
  }
  assert_eq(total, hash_count)
}

///|
test "counting cycle enumeration matches walking every probe" {
  for round = 1; round <= 100; round = round + 1 {
    let mut seed = round
    seed = wide_cycle_seed(seed)
    let h1 = (seed.to_uint64() << 9) | 0x12345UL
    seed = wide_cycle_seed(seed)
    let h2 = (seed.to_uint64() << 3) | 1UL
    let slot_count = 1 << (seed % 8 + 1)
    let hash_count = 65 + seed % 5000
    assert_cycle_matches_full_scan(h1, h2, hash_count, slot_count)
  }
  assert_cycle_matches_full_scan(0x123456789UL, 4UL, 1000, 16)
  assert_cycle_matches_full_scan(0x123456789UL, 0UL, 1000, 16)
  assert_cycle_matches_full_scan(0x123456789UL, 3UL, 1000, 48)
}

///|
test "counting cycle helper only enumerates short power-of-two cycles" {
  assert_eq(counting_short_cycle_period(3UL, 16UL), 16)
  assert_eq(counting_short_cycle_period(4UL, 16UL), 4)
  assert_eq(counting_short_cycle_period(0UL, 16UL), 1)
  assert_eq(counting_short_cycle_period(1UL, 48UL), 0)
  assert_eq(counting_short_cycle_period(1UL, 32768UL), 0)
}
