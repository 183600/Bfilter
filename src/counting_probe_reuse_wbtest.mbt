///|
test "counting filters reuse probe buffers across interleaved operations" {
  let filter = CountingBloomFilter::with_size(128, 8)
  for round = 0; round < 50; round = round + 1 {
    let key = "key-" + round.to_string()
    filter.insert(key)
    filter.insert(key)
    assert_eq(filter.count_of(key), 2)
    assert_true(filter.remove(key))
    assert_eq(filter.count_of(key), 1)

    // Copies and serialized filters must not share the reusable workspace.
    let copy = filter.copy()
    let restored = CountingBloomFilter::from_bytes(filter.to_bytes())
    assert_eq(copy.count_of(key), 1)
    assert_eq(restored.count_of(key), 1)
    assert_true(copy.remove(key))
    assert_false(copy.contains(key))
    assert_eq(restored.count_of(key), 1)

    assert_true(filter.remove(key))
    assert_false(filter.contains(key))
    assert_eq(filter.count(), 0)
  }
}

///|
test "compact counting filters reuse probe buffers across interleaved operations" {
  let filter = CompactCountingBloomFilter::with_size(128, 8)
  for round = 0; round < 50; round = round + 1 {
    let key = "key-" + round.to_string()
    filter.insert(key)
    filter.insert(key)
    assert_eq(filter.count_of(key), 2)
    assert_true(filter.remove(key))
    assert_eq(filter.count_of(key), 1)

    let copy = filter.copy()
    let restored = CompactCountingBloomFilter::from_bytes(
      filter.to_bytes(),
    )
    assert_eq(copy.count_of(key), 1)
    assert_eq(restored.count_of(key), 1)
    assert_true(copy.remove(key))
    assert_false(copy.contains(key))
    assert_eq(restored.count_of(key), 1)

    assert_true(filter.remove(key))
    assert_false(filter.contains(key))
    assert_eq(filter.count(), 0)
  }
}

///|
test "wide counting layouts reuse bounded probe scratch" {
  // The hash count is much wider than the filter, but a key can still reach
  // only sixty-four distinct slots, so the reusable workspace stays bounded
  // instead of allocating temporary position arrays on every operation.
  let wide = CountingBloomFilter::with_size(64, 2048)
  assert_eq(wide.probe_positions.length(), 64)
  wide.insert("wide")
  assert_true(wide.contains("wide"))
  let copy = wide.copy()
  assert_eq(copy.probe_positions.length(), 64)
  assert_eq(copy.count_of("wide"), wide.count_of("wide"))
  let restored = CountingBloomFilter::from_bytes(wide.to_bytes())
  assert_eq(restored.probe_positions.length(), 64)
  assert_eq(restored.count_of("wide"), wide.count_of("wide"))
  assert_true(wide.remove("wide"))
  assert_false(wide.contains("wide"))

  let compact = CompactCountingBloomFilter::with_size(64, 2048)
  assert_eq(compact.probe_positions.length(), 64)
  compact.insert("wide")
  assert_true(compact.contains("wide"))
  let compact_copy = compact.copy()
  assert_eq(compact_copy.probe_positions.length(), 64)
  assert_eq(compact_copy.count_of("wide"), compact.count_of("wide"))
  let compact_restored = CompactCountingBloomFilter::from_bytes(
    compact.to_bytes(),
  )
  assert_eq(compact_restored.probe_positions.length(), 64)
  assert_eq(compact_restored.count_of("wide"), compact.count_of("wide"))
  assert_true(compact.remove("wide"))
  assert_false(compact.contains("wide"))
}

///|
test "counting probe scratch follows the reachable slot count boundary" {
  // Sixteen slots are always the reachable maximum, however wide the hash count
  // becomes, so the workspace is retained up to the scratch limit.
  let narrow = CountingBloomFilter::with_size(16, 10_000_000)
  assert_eq(narrow.probe_positions.length(), 16)
  narrow.insert("wide")
  assert_true(narrow.contains("wide"))
  assert_true(narrow.remove("wide"))
  assert_false(narrow.contains("wide"))

  // At the limit the workspace is exactly the slot count.
  let at_limit = CountingBloomFilter::with_size(1024, 2048)
  assert_eq(at_limit.probe_positions.length(), 1024)
  at_limit.insert("limit")
  assert_true(at_limit.contains("limit"))
  assert_true(at_limit.remove("limit"))

  // One more slot would exceed the scratch bound, so the workspace is omitted
  // and operations fall back to a temporary set. The filter still works.
  let over_limit = CountingBloomFilter::with_size(1040, 2048)
  assert_eq(over_limit.probe_positions.length(), 0)
  over_limit.insert("over")
  assert_true(over_limit.contains("over"))
  assert_true(over_limit.remove("over"))

  let compact_narrow = CompactCountingBloomFilter::with_size(16, 10_000_000)
  assert_eq(compact_narrow.probe_positions.length(), 16)
  compact_narrow.insert("wide")
  assert_true(compact_narrow.contains("wide"))
  assert_true(compact_narrow.remove("wide"))
  assert_false(compact_narrow.contains("wide"))

  let compact_at_limit = CompactCountingBloomFilter::with_size(1024, 2048)
  assert_eq(compact_at_limit.probe_positions.length(), 1024)
  compact_at_limit.insert("limit")
  assert_true(compact_at_limit.contains("limit"))
  assert_true(compact_at_limit.remove("limit"))

  let compact_over_limit = CompactCountingBloomFilter::with_size(1040, 2048)
  assert_eq(compact_over_limit.probe_positions.length(), 0)
  compact_over_limit.insert("over")
  assert_true(compact_over_limit.contains("over"))
  assert_true(compact_over_limit.remove("over"))
}

///|
test "counting probe workspaces shrink to the reachable slot count" {
  let counting = CountingBloomFilter::with_size(16, 1024)
  assert_eq(counting.probe_positions.length(), 16)
  counting.insert("key")
  assert_true(counting.count_of("key") > 0)
  assert_true(counting.remove("key"))
  assert_false(counting.contains("key"))
  assert_eq(counting.probe_positions.length(), 16)

  let compact = CompactCountingBloomFilter::with_size(16, 1024)
  assert_eq(compact.probe_positions.length(), 16)
  compact.insert("key")
  assert_true(compact.count_of("key") > 0)
  assert_true(compact.remove("key"))
  assert_false(compact.contains("key"))

  // A temporary set for a wide hash count is capped by the slots a key can
  // select instead of by the number of probes.
  let (h1, h2) = key_hashes("wide")
  let set = unique_key_positions_fast(h1, h2, 1_048_576, 64UL)
  assert_eq(set.positions.length(), 64)
  assert_true(set.length > 0)
  assert_true(set.length <= 64)
  let mut occurrences = 0
  for i = 0; i < set.length; i = i + 1 {
    occurrences = occurrences + set.counts[i]
  }
  assert_eq(occurrences, 1_048_576)
}

///|
test "counting query probes stop at the double-hash cycle length" {
  assert_eq(counting_effective_probes(100, 0UL, 16UL), 1)
  assert_eq(counting_effective_probes(100, 4UL, 16UL), 4)
  assert_eq(counting_effective_probes(100, 2UL, 16UL), 8)
  assert_eq(counting_effective_probes(100, 1UL, 16UL), 16)
  assert_eq(counting_effective_probes(65, 1UL, 16UL), 16)
  assert_eq(counting_effective_probes(64, 0UL, 16UL), 64)

  let counting = CountingBloomFilter::with_size(16, 100_000)
  counting.insert("wide")
  let (h1, h2) = key_hashes("wide")
  let slot_count = counting.slot_count.to_uint64()
  let mut state = h1
  let mut full_minimum = 65535UL
  for i = 0; i < counting.hash_count; i = i + 1 {
    let value = counting.counter_at((state % slot_count).to_int())
    if value < full_minimum {
      full_minimum = value
    }
    state = state + h2
  }
  assert_eq(counting.count_of("wide"), full_minimum.to_int())
  assert_true(counting.contains("wide"))
  assert_true(counting.remove("wide"))
  assert_false(counting.contains("wide"))

  let compact = CompactCountingBloomFilter::with_size(16, 100_000)
  compact.insert("wide")
  let compact_slots = compact.slot_count.to_uint64()
  let mut compact_state = h1
  let mut compact_minimum = COMPACT_COUNTER_MAX
  for i = 0; i < compact.hash_count; i = i + 1 {
    let value = compact.counter_at((compact_state % compact_slots).to_int())
    if value < compact_minimum {
      compact_minimum = value
    }
    compact_state = compact_state + h2
  }
  assert_eq(compact.count_of("wide"), compact_minimum.to_int())
  assert_true(compact.contains("wide"))
  assert_true(compact.remove("wide"))
  assert_false(compact.contains("wide"))
}
