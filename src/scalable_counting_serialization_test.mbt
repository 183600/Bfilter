///|
test "scalable counting filter serialization round trip" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key-0")
  filter.insert("key-0")
  for i = 1; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.remove("key-1"))
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    filter.to_bytes(),
  )
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.tracked_key_count(), filter.tracked_key_count())
  assert_eq(restored.slice_count(), filter.slice_count())
  assert_eq(restored.capacity(), filter.capacity())
  assert_eq(restored.slot_count(), filter.slot_count())
  assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
  assert_eq(
    restored.target_false_positive_rate(),
    filter.target_false_positive_rate(),
  )
  assert_eq(restored.count_of("key-0"), 2)
  assert_eq(restored.count_of("key-1"), 0)
  for i = 2; i < 40; i = i + 1 {
    assert_true(restored.contains("key-" + i.to_string()))
  }
  assert_true(restored.remove("key-0"))
  assert_eq(restored.count_of("key-0"), 1)
  assert_true(restored.insert_if_absent("after-restore"))
  assert_eq(restored.count(), filter.count())
}

///|
test "scalable counting filter serialization round trips empty filters" {
  let filter = @src.ScalableCountingBloomFilter::new(16, 0.001)
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    filter.to_bytes(),
  )
  assert_true(restored.is_empty())
  assert_eq(restored.count(), 0)
  assert_eq(restored.tracked_key_count(), 0)
  assert_eq(restored.slice_count(), 1)
  assert_eq(restored.capacity(), 16L)
  assert_eq(restored.slot_count(), filter.slot_count())
}

///|
test "panic scalable counting serialization rejects wrong filter type" {
  let bloom = @src.BloomFilter::with_size(64, 1)
  @src.ScalableCountingBloomFilter::from_bytes(bloom.to_bytes()) |> ignore
  let counting = @src.CountingBloomFilter::new(4, 0.01)
  @src.CountingBloomFilter::from_bytes(counting.to_bytes()) |> ignore
  let scalable = @src.ScalableCountingBloomFilter::new(4, 0.01)
  @src.ScalableBloomFilter::from_bytes(scalable.to_bytes()) |> ignore
}

///|
test "panic scalable counting serialization rejects truncated data" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01).to_bytes()
  @src.ScalableCountingBloomFilter::from_bytes(
    bytes.exact_view(end=20).to_owned(),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects invalid target rates" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint64_le(20, 0UL)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
  bytes.unsafe_write_uint64_le(20, 1.0.reinterpret_as_uint64())
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects invalid metadata counts" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(28, 2U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects bad metadata" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(32 + 16, 5U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
  bytes.unsafe_write_uint32_le(32 + 16, 0U)
  bytes.unsafe_write_uint32_le(32 + 20, 0U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects mismatched layouts" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(32 + 24 + 8, 128U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects trailing data" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .add(b"\x00")
  @src.ScalableCountingBloomFilter::from_bytes(bytes) |> ignore
}

///|
test "panic scalable counting serialization rejects bad slice lengths" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(32 + 24, 19U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects mismatched insertion counts" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 99U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}
