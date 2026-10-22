///|
fn counting_full_probe_minimum(
  filter : CountingBloomFilter,
  key : String,
) -> Int32 {
  let (h1, h2) = key_hashes(key)
  let slot_count = filter.slot_count.to_uint64()
  let mut state = h1
  let mut minimum = CountingBloomFilter::counter_max().to_uint64()
  for i = 0; i < filter.hash_count; i = i + 1 {
    let value = filter.counter_at((state % slot_count).to_int())
    if value < minimum {
      minimum = value
    }
    state = state + h2
  }
  minimum.to_int()
}

///|
fn compact_full_probe_minimum(
  filter : CompactCountingBloomFilter,
  key : String,
) -> Int32 {
  let (h1, h2) = key_hashes(key)
  let slot_count = filter.slot_count.to_uint64()
  let mut state = h1
  let mut minimum = CompactCountingBloomFilter::counter_max().to_uint64()
  for i = 0; i < filter.hash_count; i = i + 1 {
    let value = filter.counter_at((state % slot_count).to_int())
    if value < minimum {
      minimum = value
    }
    state = state + h2
  }
  minimum.to_int()
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
  assert_eq(counting.count_of(key), 12)

  let compact = CompactCountingBloomFilter::with_size(48, 720)
  compact.insert(key)
  assert_eq(compact.count_of(key), compact_full_probe_minimum(compact, key))
}

///|
test "counting queries still stop at a cycle for power-of-two slots" {
  assert_eq(counting_effective_probes(100, 1UL, 16UL), 16)
  assert_eq(counting_effective_probes(100, 4UL, 16UL), 4)
  assert_eq(counting_effective_probes(100, 0UL, 16UL), 1)
  // Four is not a power of two, so its wraparound-sensitive slots retain the
  // full probe count unless the step is zero.
  assert_eq(counting_effective_probes(100, 1UL, 48UL), 100)
  assert_eq(counting_effective_probes(100, 0UL, 48UL), 1)
}
