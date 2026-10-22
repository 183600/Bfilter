///|
test "counting duplicate-position saturation drains every selected lane" {
  // 65535 probes over 16 slots select 15 slots 4096 times and one slot 4095
  // times. Their counter caps are therefore different multiples of the probe
  // count; advancing the unsaturated lanes independently used to leave one
  // positive counter that no later removal could drain.
  let filter = @src.CountingBloomFilter::with_size(16, 65535)
  for i = 0; i < 40; i = i + 1 {
    filter.insert(0)
  }
  let mut removed = 0
  while filter.remove(0) {
    removed = removed + 1
  }
  assert_eq(removed, 15)
  assert_false(filter.contains(0))
  assert_eq(filter.count_of(0), 0)
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.count(), 25)
  assert_false(filter.remove(0))
  assert_eq(filter.occupied_slot_count(), 0)
  let restored = @src.CountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.occupied_slot_count(), 0)
}

///|
test "compact counting duplicate-position saturation drains every selected lane" {
  // Seventeen probes over sixteen slots select one slot twice and the rest
  // once, so the saturated lanes reach different multiples of their probe
  // counts. All lanes must stop together to stay removable.
  let filter = @src.CompactCountingBloomFilter::with_size(16, 17)
  for i = 0; i < 40; i = i + 1 {
    filter.insert(0)
  }
  let mut removed = 0
  while filter.remove(0) {
    removed = removed + 1
  }
  assert_eq(removed, 7)
  assert_false(filter.contains(0))
  assert_eq(filter.count_of(0), 0)
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.count(), 33)
  assert_false(filter.remove(0))
  assert_eq(filter.occupied_slot_count(), 0)
  let restored = @src.CompactCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.occupied_slot_count(), 0)
}
