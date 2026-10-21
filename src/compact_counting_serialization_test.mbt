///|
test "compact counting filter serialization round trip" {
  let filter = @src.CompactCountingBloomFilter::new(100, 0.01)
  for i = 0; i < 100; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  filter.insert("key-0")
  assert_true(filter.remove("key-1"))
  let restored = @src.CompactCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.slot_count(), filter.slot_count())
  assert_eq(restored.hash_count(), filter.hash_count())
  assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
  assert_eq(restored.memory_bytes(), filter.memory_bytes())
  assert_eq(restored.count_of("key-0"), 2)
  assert_false(restored.contains("key-1"))
  for i = 2; i < 100; i = i + 1 {
    assert_true(restored.contains("key-" + i.to_string()))
  }
  assert_true(restored.remove("key-0"))
  assert_eq(restored.count_of("key-0"), 1)
}

///|
test "compact counting filter serialization round trips empty filters" {
  let filter = @src.CompactCountingBloomFilter::new(16, 0.001)
  let restored = @src.CompactCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.count(), 0)
  assert_eq(restored.slot_count(), filter.slot_count())
}

///|
test "panic compact counting serialization rejects wrong filter type" {
  let bloom = @src.BloomFilter::with_size(64, 1)
  @src.CompactCountingBloomFilter::from_bytes(bloom.to_bytes()) |> ignore
  let compact = @src.CompactCountingBloomFilter::new(4, 0.01)
  @src.CountingBloomFilter::from_bytes(compact.to_bytes()) |> ignore
}

///|
test "panic compact counting serialization rejects truncated data" {
  let bytes = @src.CompactCountingBloomFilter::new(4, 0.01).to_bytes()
  @src.CompactCountingBloomFilter::from_bytes(
    bytes.exact_view(end=20).to_owned(),
  )
  |> ignore
}

///|
test "panic compact counting serialization rejects invalid slot counts" {
  let bytes = @src.CompactCountingBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 0U)
  @src.CompactCountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
  bytes.unsafe_write_uint32_le(8, 20U)
  @src.CompactCountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic compact counting serialization rejects invalid hash counts" {
  let bytes = @src.CompactCountingBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 0U)
  @src.CompactCountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic compact counting serialization rejects trailing data" {
  let bytes = @src.CompactCountingBloomFilter::new(4, 0.01).to_bytes().add(b"\x00")
  @src.CompactCountingBloomFilter::from_bytes(bytes) |> ignore
}

///|
test "panic compact counting serialization rejects inconsistent counters" {
  let bytes = @src.CompactCountingBloomFilter::with_size(16, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint64_le(20, 0xFFFFUL)
  @src.CompactCountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}
