///|
test "counting non-power-of-two layouts remove repeated probe contributions" {
  let layouts : Array[(Int32, Int32)] = [(48, 720), (80, 540), (96, 720)]
  for index = 0; index < layouts.length(); index = index + 1 {
    let (slots, hashes) = layouts[index]
    let filter = @src.CountingBloomFilter::with_size(slots, hashes)
    let key = "wide-" + slots.to_string()
    for i = 0; i < 3; i = i + 1 {
      filter.insert(key)
      assert_true(filter.contains(key))
    }
    assert_true(filter.count_of(key) >= 3)
    let restored = @src.CountingBloomFilter::from_bytes(filter.to_bytes())
    assert_eq(restored.count_of(key), filter.count_of(key))
    assert_true(restored.contains(key))
    for i = 0; i < 3; i = i + 1 {
      assert_true(filter.remove(key))
    }
    assert_false(filter.contains(key))
    assert_eq(filter.occupied_slot_count(), 0)
    assert_eq(filter.count(), 0)
  }
}

///|
test "compact counting non-power-of-two layouts drain repeated probes" {
  // A non-power-of-two slot count keeps the full probe walk, and a wider hash
  // count may select some slots several times. One insertion and removal must
  // still leave no residue even when a nibble saturates at its insertion cap.
  let layouts : Array[(Int32, Int32)] = [(48, 15), (80, 15), (96, 15)]
  for index = 0; index < layouts.length(); index = index + 1 {
    let (slots, hashes) = layouts[index]
    let filter = @src.CompactCountingBloomFilter::with_size(slots, hashes)
    let key = "compact-" + slots.to_string()
    filter.insert(key)
    assert_true(filter.contains(key))
    assert_true(filter.count_of(key) >= 1)
    let restored = @src.CompactCountingBloomFilter::from_bytes(
      filter.to_bytes(),
    )
    assert_true(restored.contains(key))
    assert_true(filter.remove(key))
    assert_false(filter.contains(key))
    assert_eq(filter.occupied_slot_count(), 0)
    assert_eq(filter.count(), 0)
  }
}
