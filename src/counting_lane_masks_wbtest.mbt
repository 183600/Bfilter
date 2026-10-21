///|
test "counting lane helpers match per-lane scans" {
  let words : Array[UInt64] = [
    0UL,
    1UL,
    0x8000UL,
    0xFFFFUL,
    0x0001000200030004UL,
    0x8000800080008000UL,
    0xFFFFFFFFFFFFFFFFUL,
  ]
  for word in words {
    let mut expected_mask = 0UL
    let mut expected_mass = 0UL
    for lane = 0; lane < 4; lane = lane + 1 {
      let value = (word >> (lane * 16)) & 0xFFFFUL
      if value != 0UL {
        expected_mask = expected_mask | (0x8000UL << (lane * 16))
      }
      expected_mass = expected_mass + value
    }
    assert_eq(counting_nonzero_lanes(word), expected_mask)
    assert_eq(counting_word_mass(word), expected_mass)
  }
}

///|
test "compact lane helpers match per-lane scans" {
  let words : Array[UInt64] = [
    0UL,
    1UL,
    8UL,
    0xFUL,
    0x123456789ABCDEF0UL,
    0x8888888888888888UL,
    0xFFFFFFFFFFFFFFFFUL,
  ]
  for word in words {
    let mut expected_mask = 0UL
    let mut expected_mass = 0UL
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      let value = (word >> (lane * 4)) & COMPACT_COUNTER_MAX
      if value != 0UL {
        expected_mask = expected_mask | (0x8UL << (lane * 4))
      }
      expected_mass = expected_mass + value
    }
    assert_eq(compact_nonzero_lanes(word), expected_mask)
    assert_eq(compact_word_mass(word), expected_mass)
  }
}

///|
test "counting set operations handle high-bit counters" {
  let left = CountingBloomFilter::with_size(16, 1)
  let right = CountingBloomFilter::with_size(16, 1)
  left.set_counter(0, 0x8000UL)
  right.set_counter(0, 1UL)
  assert_eq(left.occupied_slot_count(), 1)
  assert_eq(right.occupied_slot_count(), 1)
  assert_false(left.is_disjoint_from(right))
  assert_false(right.is_disjoint_from(left))
  assert_false(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_eq(left.intersection(right).counter_at(0), 1UL)
  assert_eq(left.union(right).counter_at(0), 0x8000UL)
  let empty = CountingBloomFilter::with_size(16, 1)
  assert_true(empty.is_disjoint_from(left))
  assert_true(empty.is_subset_of(left))
  let merged = left.copy()
  merged.merge(empty)
  assert_eq(merged.counter_at(0), 0x8000UL)
  assert_eq(merged.counter_mass, 0x8000UL)
}

///|
test "compact set operations handle high-bit counters" {
  let left = CompactCountingBloomFilter::with_size(16, 1)
  let right = CompactCountingBloomFilter::with_size(16, 1)
  left.set_counter(0, 8UL)
  right.set_counter(0, 7UL)
  assert_eq(left.occupied_slot_count(), 1)
  assert_eq(right.occupied_slot_count(), 1)
  assert_false(left.is_disjoint_from(right))
  assert_false(right.is_disjoint_from(left))
  assert_false(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_eq(left.intersection(right).counter_at(0), 7UL)
  assert_eq(left.union(right).counter_at(0), 8UL)
  let empty = CompactCountingBloomFilter::with_size(16, 1)
  assert_true(empty.is_disjoint_from(left))
  assert_true(empty.is_subset_of(left))
  let merged = left.copy()
  merged.merge(empty)
  assert_eq(merged.counter_at(0), 8UL)
  assert_eq(merged.counter_mass, 8UL)
}
