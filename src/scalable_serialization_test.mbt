///|
test "scalable bloom filter serialization round trip" {
  let filter = @src.ScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  let restored = @src.ScalableBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.slice_count(), filter.slice_count())
  assert_eq(restored.capacity(), filter.capacity())
  assert_eq(restored.bit_count(), filter.bit_count())
  assert_eq(restored.set_bit_count(), filter.set_bit_count())
  assert_eq(
    restored.target_false_positive_rate(),
    filter.target_false_positive_rate(),
  )
  for i = 0; i < 40; i = i + 1 {
    assert_true(restored.contains("key-" + i.to_string()))
  }
  assert_true(restored.insert_if_absent("after-restore"))
  assert_eq(restored.count(), filter.count() + 1)
}

///|
test "scalable bloom filter serialization round trips empty filters" {
  let filter = @src.ScalableBloomFilter::new(16, 0.001)
  let restored = @src.ScalableBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.slice_count(), 1)
  assert_eq(restored.capacity(), 16L)
  assert_eq(restored.count(), 0)
  assert_eq(restored.bit_count(), filter.bit_count())
}

///|
test "panic scalable bloom serialization rejects wrong filter type" {
  let bloom = @src.BloomFilter::with_size(64, 1)
  @src.ScalableBloomFilter::from_bytes(bloom.to_bytes()) |> ignore
  let scalable = @src.ScalableBloomFilter::new(4, 0.01)
  @src.BloomFilter::from_bytes(scalable.to_bytes()) |> ignore
}

///|
test "panic scalable bloom serialization rejects truncated data" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes()
  @src.ScalableBloomFilter::from_bytes(bytes.exact_view(end=20).to_owned())
  |> ignore
}

///|
test "panic scalable bloom serialization rejects invalid slice counts" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 0U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
  bytes.unsafe_write_uint32_le(8, 65U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable bloom serialization rejects invalid target rates" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint64_le(20, 0UL)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
  bytes.unsafe_write_uint64_le(20, 1.0.reinterpret_as_uint64())
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable bloom serialization rejects trailing data" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().add(b"\x00")
  @src.ScalableBloomFilter::from_bytes(bytes) |> ignore
}

///|
test "panic scalable bloom serialization rejects mismatched insertion counts" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 1U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable bloom serialization rejects invalid slice lengths" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(28, 19U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable bloom serialization rejects mismatched slice layouts" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(28 + 8, 128U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}
