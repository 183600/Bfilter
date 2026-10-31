///|
test "empty counting filter answers wide non-cyclic queries immediately" {
  // Forty-eight slots are not a power of two, so the double-hash cycle shortcut
  // does not apply and a query would otherwise walk the full nominal hash count.
  let counting = CountingBloomFilter::with_size(48, 1_000_000_000)
  assert_eq(counting.counter_mass, 0UL)
  assert_eq(counting.occupied_slot_count(), 0)
  assert_false(counting.contains("absent"))
  assert_eq(counting.count_of("absent"), 0)
  assert_false(counting.remove("absent"))
  assert_eq(counting.count(), 0)
  assert_eq(counting.counter_mass, 0UL)

  let compact = CompactCountingBloomFilter::with_size(48, 1_000_000_000)
  assert_eq(compact.counter_mass, 0UL)
  assert_eq(compact.occupied_slot_count(), 0)
  assert_false(compact.contains("absent"))
  assert_eq(compact.count_of("absent"), 0)
  assert_false(compact.remove("absent"))
  assert_eq(compact.count(), 0)
  assert_eq(compact.counter_mass, 0UL)
}

///|
test "full counting filter answers wide non-cyclic queries immediately" {
  let counting = CountingBloomFilter::with_size(48, 1_000_000_000)
  for slot = 0; slot < counting.slot_count; slot = slot + 1 {
    counting.set_counter(slot, 1UL)
  }
  assert_eq(counting.occupied_slot_count(), counting.slot_count)
  assert_true(counting.contains("any-key"))
  assert_false(counting.insert_if_absent("any-key"))
  assert_eq(counting.insert_all_if_absent(["one", "two"]), 0)
  assert_eq(counting.count(), 0)

  let compact = CompactCountingBloomFilter::with_size(48, 1_000_000_000)
  for slot = 0; slot < compact.slot_count; slot = slot + 1 {
    compact.set_counter(slot, 1UL)
  }
  assert_eq(compact.occupied_slot_count(), compact.slot_count)
  assert_true(compact.contains("any-key"))
  assert_false(compact.insert_if_absent("any-key"))
  assert_eq(compact.insert_all_if_absent(["one", "two"]), 0)
  assert_eq(compact.count(), 0)
}

///|
test "empty non-power-of-two bloom filter misses without probing" {
  // The bit count is a non-power-of-two multiple of 64, so the double-hash cycle
  // shortcut does not apply. An empty filter must still answer immediately.
  let bloom = BloomFilter::with_size(192, 1_000_000_000)
  assert_eq(bloom.set_bit_count(), 0)
  assert_false(bloom.contains("absent"))
  assert_false(bloom.contains_any(["a", "b"]))
  assert_eq(bloom.count(), 0)
}

///|
test "empty wide filters still accept keys after a failed removal" {
  let counting = CountingBloomFilter::with_size(48, 720)
  assert_false(counting.remove("never"))
  assert_true(counting.insert_if_absent("first"))
  assert_true(counting.contains("first"))
  assert_eq(counting.count(), 1)
  assert_true(counting.remove("first"))
  assert_eq(counting.count(), 0)

  let compact = CompactCountingBloomFilter::with_size(48, 720)
  assert_false(compact.remove("never"))
  assert_true(compact.insert_if_absent("first"))
  assert_true(compact.contains("first"))
  assert_eq(compact.count(), 1)
  assert_true(compact.remove("first"))
  assert_eq(compact.count(), 0)
}

///|
test "empty wide filters answer occupancy introspection immediately" {
  let bloom = BloomFilter::with_size(1_000_000, 1_000_000_000)
  assert_eq(bloom.set_bit_count(), 0)
  assert_false(bloom.is_full())
  assert_eq(bloom.estimated_item_count(), 0.0)
  assert_eq(bloom.fill_ratio(), 0.0)

  let blocked = BlockedBloomFilter::with_size(1_000_000, 1_000_000_000)
  assert_eq(blocked.set_bit_count(), 0)
  assert_false(blocked.is_full())
  assert_eq(blocked.estimated_item_count(), 0.0)
  assert_eq(blocked.fill_ratio(), 0.0)

  let counting = CountingBloomFilter::with_size(1_000_000, 1_000_000_000)
  assert_eq(counting.occupied_slot_count(), 0)
  assert_eq(counting.fill_ratio(), 0.0)

  let compact = CompactCountingBloomFilter::with_size(
    1_000_000, 1_000_000_000,
  )
  assert_eq(compact.occupied_slot_count(), 0)
  assert_eq(compact.fill_ratio(), 0.0)

  let live_bloom = BloomFilter::with_size(1_000_000, 4)
  assert_true(live_bloom.insert_if_absent("first"))
  assert_true(live_bloom.set_bit_count() > 0)
  assert_false(live_bloom.is_full())

  let live_blocked = BlockedBloomFilter::with_size(1_000_000, 4)
  assert_true(live_blocked.insert_if_absent("first"))
  assert_true(live_blocked.set_bit_count() > 0)
  assert_false(live_blocked.is_full())

  let live_counting = CountingBloomFilter::with_size(1_000_000, 4)
  assert_true(live_counting.insert_if_absent("first"))
  assert_true(live_counting.occupied_slot_count() > 0)

  let live_compact = CompactCountingBloomFilter::with_size(1_000_000, 4)
  assert_true(live_compact.insert_if_absent("first"))
  assert_true(live_compact.occupied_slot_count() > 0)
}
