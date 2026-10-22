///|
fn counting_full_probe_minimum(
  filter : CountingBloomFilter,
  key : String,
) -> Int32 {
  let (h1, h2) = key_hashes(key)
  let slot_count = filter.slot_count.to_uint64()
  let occurrences : FixedArray[Int32] = FixedArray::make(
    filter.slot_count,
    0,
  )
  let mut state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let position = (state % slot_count).to_int()
    occurrences[position] = occurrences[position] + 1
    state = state + h2
  }
  let limit = CountingBloomFilter::counter_max()
  let limit_u64 = limit.to_uint64()
  let mut minimum = limit
  let mut fallback = limit
  let mut have_estimate = false
  for position = 0; position < filter.slot_count; position = position + 1 {
    if occurrences[position] == 0 {
      continue
    }
    let value = filter.counter_at(position)
    if value == 0UL {
      return 0
    }
    let raw = if value > limit_u64 { limit } else { value.to_int() }
    if raw < fallback {
      fallback = raw
    }
    let count = occurrences[position].to_uint64()
    if count <= limit_u64 {
      let estimate_u64 = if value < count { 1UL } else { value / count }
      let estimate = if estimate_u64 > limit_u64 {
        limit
      } else {
        estimate_u64.to_int()
      }
      if !have_estimate || estimate < minimum {
        minimum = estimate
        have_estimate = true
      }
    }
  }
  if have_estimate {
    minimum
  } else {
    fallback
  }
}

///|
fn compact_full_probe_minimum(
  filter : CompactCountingBloomFilter,
  key : String,
) -> Int32 {
  let (h1, h2) = key_hashes(key)
  let slot_count = filter.slot_count.to_uint64()
  let occurrences : FixedArray[Int32] = FixedArray::make(
    filter.slot_count,
    0,
  )
  let mut state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let position = (state % slot_count).to_int()
    occurrences[position] = occurrences[position] + 1
    state = state + h2
  }
  let limit = CompactCountingBloomFilter::counter_max()
  let limit_u64 = limit.to_uint64()
  let mut minimum = limit
  let mut fallback = limit
  let mut have_estimate = false
  for position = 0; position < filter.slot_count; position = position + 1 {
    if occurrences[position] == 0 {
      continue
    }
    let value = filter.counter_at(position)
    if value == 0UL {
      return 0
    }
    let raw = if value > limit_u64 { limit } else { value.to_int() }
    if raw < fallback {
      fallback = raw
    }
    let count = occurrences[position].to_uint64()
    if count <= limit_u64 {
      let estimate_u64 = if value < count { 1UL } else { value / count }
      let estimate = if estimate_u64 > limit_u64 {
        limit
      } else {
        estimate_u64.to_int()
      }
      if !have_estimate || estimate < minimum {
        minimum = estimate
        have_estimate = true
      }
    }
  }
  if have_estimate {
    minimum
  } else {
    fallback
  }
}

///|
test "counting queries scan every probe on non-power-of-two slots" {
  // The slot count is not a power of two, so a 64-bit wrap can move later
  // probes outside the first double-hash cycle. The query must keep scanning
  // instead of stopping at that cycle.
  let key = "cycle-1"
  let counting = CountingBloomFilter::with_size(48, 720)
  counting.insert(key)
  assert_eq(counting.count_of(key), counting_full_probe_minimum(counting, key))

  let compact = CompactCountingBloomFilter::with_size(48, 720)
  compact.insert(key)
  assert_eq(compact.count_of(key), compact_full_probe_minimum(compact, key))
}

///|
test "counting queries still stop at a cycle for power-of-two slots" {
  assert_eq(counting_effective_probes(100, 1UL, 16UL), 16)
  assert_eq(counting_effective_probes(100, 4UL, 16UL), 4)
  assert_eq(counting_effective_probes(100, 0UL, 16UL), 1)
  // Forty-eight is not a power of two, so its wraparound-sensitive slots
  // retain the full probe count unless the step is zero.
  assert_eq(counting_effective_probes(100, 1UL, 48UL), 100)
  assert_eq(counting_effective_probes(100, 0UL, 48UL), 1)
  // A nonzero step that is a multiple of the slot count still only looks
  // constant until the 64-bit state wraps. Wrapping subtracts 2^64, which is
  // not a multiple of 48, so later probes can land on other slots.
  assert_eq(counting_effective_probes(100, 48UL, 48UL), 100)
  assert_eq(counting_effective_probes(100, 96UL, 48UL), 100)
}
