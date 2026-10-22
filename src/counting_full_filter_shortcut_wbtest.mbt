///|
test "counting full-filter shortcut follows the packed word width" {
  let counting = CountingBloomFilter::with_size(2048, 1)
  assert_eq(counting.counters.length(), 512)
  assert_false(counting_should_check_full(512, counting.counters.length()))
  assert_true(counting_should_check_full(513, counting.counters.length()))

  let compact = CompactCountingBloomFilter::with_size(2048, 1)
  assert_eq(compact.counters.length(), 128)
  assert_false(counting_should_check_full(128, compact.counters.length()))
  assert_true(counting_should_check_full(129, compact.counters.length()))
}

///|
test "full power-of-two counting filters short-circuit wide probe walks" {
  let counting = CountingBloomFilter::with_size(2048, 1)
  for slot = 0; slot < counting.slot_count; slot = slot + 1 {
    counting.set_counter(slot, 1UL)
  }
  counting.inserted = 2
  let counting_bytes = counting.to_bytes().to_fixedarray()
  // Keep every counter positive but use a hash count that is below the slot
  // count; the effective walk still exceeds the 512 packed counter words.
  counting_bytes.unsafe_write_uint32_le(12, 1025U)
  let full_counting = CountingBloomFilter::from_bytes(
    Bytes::from_array(counting_bytes.exact_view()),
  )
  assert_eq(full_counting.hash_count(), 1025)
  assert_eq(full_counting.occupied_slot_count(), 2048)
  assert_true(full_counting.contains("anything"))
  assert_true(full_counting.contains_all(["a", "b"]))
  assert_false(full_counting.insert_if_absent("anything"))
  assert_eq(full_counting.insert_all_if_absent(["a", "b"]), 0)
  assert_eq(full_counting.count(), 2)
  let restored_counting = CountingBloomFilter::from_bytes(
    full_counting.to_bytes(),
  )
  assert_eq(restored_counting.count(), full_counting.count())
  assert_eq(restored_counting.occupied_slot_count(), 2048)
  assert_true(restored_counting.contains("anything"))

  let compact = CompactCountingBloomFilter::with_size(2048, 1)
  for slot = 0; slot < compact.slot_count; slot = slot + 1 {
    compact.set_counter(slot, 1UL)
  }
  compact.inserted = 2
  let compact_bytes = compact.to_bytes().to_fixedarray()
  compact_bytes.unsafe_write_uint32_le(12, 1025U)
  let full_compact = CompactCountingBloomFilter::from_bytes(
    Bytes::from_array(compact_bytes.exact_view()),
  )
  assert_eq(full_compact.hash_count(), 1025)
  assert_eq(full_compact.occupied_slot_count(), 2048)
  assert_true(full_compact.contains("anything"))
  assert_true(full_compact.contains_all(["a", "b"]))
  assert_false(full_compact.insert_if_absent("anything"))
  assert_eq(full_compact.insert_all_if_absent(["a", "b"]), 0)
  assert_eq(full_compact.count(), 2)
  let restored_compact = CompactCountingBloomFilter::from_bytes(
    full_compact.to_bytes(),
  )
  assert_eq(restored_compact.count(), full_compact.count())
  assert_eq(restored_compact.occupied_slot_count(), 2048)
  assert_true(restored_compact.contains("anything"))
}
