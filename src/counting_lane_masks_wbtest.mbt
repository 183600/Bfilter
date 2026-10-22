///|
test "counting lane helpers match per-lane scans" {
  let words : Array[UInt64] = [
    0UL, 1UL, 0x8000UL, 0xFFFFUL, 0x0001000200030004UL, 0x8000800080008000UL, 0xFFFFFFFFFFFFFFFFUL,
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
    0UL, 1UL, 8UL, 0xFUL, 0x123456789ABCDEF0UL, 0x8888888888888888UL, 0xFFFFFFFFFFFFFFFFUL,
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

///|
fn lane_probe_word(state : Int32) -> (UInt64, Int32) {
  let next = (state * 1103515245 + 12345) & 0x7FFFFFFF
  let higher = (next * 1103515245 + 12345) & 0x7FFFFFFF
  ((next.to_uint64() << 32) | higher.to_uint64(), higher)
}

///|
test "counting lane comparison helpers match per-lane scans" {
  let samples : Array[(UInt64, UInt64)] = [
    (0UL, 0UL),
    (0x000000000000FFFFUL, 0xFFFF000000000000UL),
    (0x8000800080008000UL, 0x7FFF7FFF7FFF7FFFUL),
    (0x7FFF7FFF7FFF7FFFUL, 0x8000800080008000UL),
    (0xFFFFFFFFFFFFFFFFUL, 0UL),
    (0UL, 0xFFFFFFFFFFFFFFFFUL),
    (0x8000000000000001UL, 0x8000000000000000UL),
    (0x0000000000008000UL, 0x0000000000008001UL),
  ]
  let mut state = 0x2468ACE
  for round = 0; round < 256; round = round + 1 {
    let (left, next) = lane_probe_word(state)
    let (right, next2) = lane_probe_word(next)
    state = next2
    samples.push((left, right))
  }
  for sample in samples {
    let (left, right) = sample
    let mut expected_max = 0UL
    let mut expected_min = 0UL
    let mut expected_at_least = 0UL
    for lane = 0; lane < 4; lane = lane + 1 {
      let shift = lane * 16
      let a = (left >> shift) & 0xFFFFUL
      let b = (right >> shift) & 0xFFFFUL
      let high = if a > b { a } else { b }
      let low = if a < b { a } else { b }
      expected_max = expected_max | (high << shift)
      expected_min = expected_min | (low << shift)
      if a >= b {
        expected_at_least = expected_at_least | (0x8000UL << shift)
      }
    }
    assert_eq(counting_lane_max(left, right), expected_max)
    assert_eq(counting_lane_min(left, right), expected_min)
    assert_eq(counting_lane_at_least(left, right), expected_at_least)
  }
}

///|
test "compact lane comparison helpers match per-lane scans" {
  let samples : Array[(UInt64, UInt64)] = [
    (0UL, 0UL),
    (0x000000000000000FUL, 0xF000000000000000UL),
    (0x8888888888888888UL, 0x7777777777777777UL),
    (0x7777777777777777UL, 0x8888888888888888UL),
    (0xFFFFFFFFFFFFFFFFUL, 0UL),
    (0UL, 0xFFFFFFFFFFFFFFFFUL),
    (0x8000000000000001UL, 0x8888888888888887UL),
  ]
  let mut state = 0x13579BD
  for round = 0; round < 256; round = round + 1 {
    let (left, next) = lane_probe_word(state)
    let (right, next2) = lane_probe_word(next)
    state = next2
    samples.push((left, right))
  }
  for sample in samples {
    let (left, right) = sample
    let mut expected_max = 0UL
    let mut expected_min = 0UL
    let mut expected_at_least = 0UL
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      let shift = lane * 4
      let a = (left >> shift) & COMPACT_COUNTER_MAX
      let b = (right >> shift) & COMPACT_COUNTER_MAX
      let high = if a > b { a } else { b }
      let low = if a < b { a } else { b }
      expected_max = expected_max | (high << shift)
      expected_min = expected_min | (low << shift)
      if a >= b {
        expected_at_least = expected_at_least | (0x8UL << shift)
      }
    }
    assert_eq(compact_lane_max(left, right), expected_max)
    assert_eq(compact_lane_min(left, right), expected_min)
    assert_eq(compact_lane_at_least(left, right), expected_at_least)
  }
}

///|
test "counting set operations match packed lane helpers" {
  let left = CountingBloomFilter::with_size(16, 1)
  let right = CountingBloomFilter::with_size(16, 1)
  left.set_counter(0, 0x8000UL)
  left.set_counter(1, 5UL)
  left.set_counter(2, 1UL)
  right.set_counter(0, 1UL)
  right.set_counter(1, 7UL)
  right.set_counter(3, 9UL)
  let combined = left.union(right)
  assert_eq(combined.counter_at(0), counting_lane_max(0x8000UL, 1UL))
  assert_eq(combined.counter_at(1), 7UL)
  assert_eq(combined.counter_at(2), 1UL)
  assert_eq(combined.counter_at(3), 9UL)
  let common = left.intersection(right)
  assert_eq(common.counter_at(0), 1UL)
  assert_eq(common.counter_at(1), 5UL)
  assert_eq(common.counter_at(2), 0UL)
  assert_eq(common.counter_at(3), 0UL)
  assert_false(left.is_subset_of(right))
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
}

///|
test "compact set operations match packed lane helpers" {
  let left = CompactCountingBloomFilter::with_size(16, 1)
  let right = CompactCountingBloomFilter::with_size(16, 1)
  left.set_counter(0, 8UL)
  left.set_counter(1, 5UL)
  left.set_counter(2, 1UL)
  right.set_counter(0, 7UL)
  right.set_counter(1, 9UL)
  right.set_counter(3, 9UL)
  let combined = left.union(right)
  assert_eq(combined.counter_at(0), 8UL)
  assert_eq(combined.counter_at(1), 9UL)
  assert_eq(combined.counter_at(2), 1UL)
  assert_eq(combined.counter_at(3), 9UL)
  let common = left.intersection(right)
  assert_eq(common.counter_at(0), 7UL)
  assert_eq(common.counter_at(1), 5UL)
  assert_eq(common.counter_at(2), 0UL)
  assert_eq(common.counter_at(3), 0UL)
  assert_false(left.is_subset_of(right))
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
}
