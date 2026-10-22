///|
test "blocked bloom filter serialization round trip" {
  let filter = @src.BlockedBloomFilter::with_size(4096, 5)
  let keys = ["alpha", "beta", "gamma", "delta"]
  filter.insert_all(keys)
  filter.insert(42)
  let restored = @src.BlockedBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.bit_count(), filter.bit_count())
  assert_eq(restored.block_count(), filter.block_count())
  assert_eq(restored.hash_count(), filter.hash_count())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.set_bit_count(), filter.set_bit_count())
  assert_true(restored.contains_all(keys))
  assert_true(restored.contains(42))
  restored.insert("restored")
  assert_eq(filter.count(), 5)
  assert_eq(restored.count(), 6)
}

///|
test "blocked bloom filter serialization round trips empty filters" {
  let filter = @src.BlockedBloomFilter::with_size(1024, 3)
  let restored = @src.BlockedBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.bit_count(), 1024)
  assert_eq(restored.block_count(), 2)
  assert_eq(restored.count(), 0)
}

///|
test "panic blocked bloom serialization rejects wrong filter type" {
  let bloom = @src.BloomFilter::with_size(64, 1)
  @src.BlockedBloomFilter::from_bytes(bloom.to_bytes()) |> ignore
  let blocked = @src.BlockedBloomFilter::with_size(512, 1)
  @src.BloomFilter::from_bytes(blocked.to_bytes()) |> ignore
}

///|
test "panic blocked bloom serialization rejects invalid bit counts" {
  let bytes = @src.BlockedBloomFilter::with_size(512, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 513U)
  @src.BlockedBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic blocked bloom serialization rejects invalid hash counts" {
  let bytes = @src.BlockedBloomFilter::with_size(512, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 0U)
  @src.BlockedBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic blocked bloom serialization rejects counts below set bits" {
  let filter = @src.BlockedBloomFilter::with_size(512, 1)
  filter.insert("stored")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 0U)
  @src.BlockedBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic blocked bloom serialization rejects trailing data" {
  let bytes = @src.BlockedBloomFilter::with_size(512, 1).to_bytes().add(b"\x00")
  @src.BlockedBloomFilter::from_bytes(bytes) |> ignore
}

///|
test "panic blocked bloom serialization rejects bits beyond one insertion per block" {
  let filter = @src.BlockedBloomFilter::with_size(1024, 1024)
  filter.insert("seed")
  let bytes = filter.to_bytes().to_fixedarray()
  // Fill both 512-bit blocks while the header still claims one insertion.
  for i = 0; i < 128; i = i + 1 {
    bytes[20 + i] = b'\xFF'
  }
  @src.BlockedBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic blocked bloom serialization rejects more blocks than insertions" {
  let bytes = @src.BlockedBloomFilter::with_size(1536, 100)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2U)
  // One bit in each of the three blocks: few set bits, but too many blocks for
  // only two insertions.
  bytes[20] = b'\x01'
  bytes[20 + 64] = b'\x01'
  bytes[20 + 128] = b'\x01'
  @src.BlockedBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}
