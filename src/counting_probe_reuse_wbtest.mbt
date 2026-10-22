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
test "wide counting layouts skip probe scratch but remain fully usable" {
  let wide = CountingBloomFilter::with_size(64, 2048)
  assert_eq(wide.probe_positions.length(), 0)
  wide.insert("wide")
  assert_true(wide.contains("wide"))
  let copy = wide.copy()
  assert_eq(copy.probe_positions.length(), 0)
  assert_eq(copy.count_of("wide"), wide.count_of("wide"))
  let restored = CountingBloomFilter::from_bytes(wide.to_bytes())
  assert_eq(restored.probe_positions.length(), 0)
  assert_eq(restored.count_of("wide"), wide.count_of("wide"))
  assert_true(wide.remove("wide"))
  assert_false(wide.contains("wide"))

  let compact = CompactCountingBloomFilter::with_size(64, 2048)
  assert_eq(compact.probe_positions.length(), 0)
  compact.insert("wide")
  assert_true(compact.contains("wide"))
  let compact_copy = compact.copy()
  assert_eq(compact_copy.probe_positions.length(), 0)
  assert_eq(compact_copy.count_of("wide"), compact.count_of("wide"))
  let compact_restored = CompactCountingBloomFilter::from_bytes(
    compact.to_bytes(),
  )
  assert_eq(compact_restored.probe_positions.length(), 0)
  assert_eq(compact_restored.count_of("wide"), compact.count_of("wide"))
  assert_true(compact.remove("wide"))
  assert_false(compact.contains("wide"))
}
