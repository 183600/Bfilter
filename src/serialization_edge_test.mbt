///|
test "panic scalable bloom serialization rejects zero initial capacity" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 0U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable bloom serialization rejects too many slices" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 65U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable bloom serialization rejects truncated slice headers" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes()
  @src.ScalableBloomFilter::from_bytes(bytes.exact_view(end=28).to_owned())
  |> ignore
}

///|
test "panic scalable bloom serialization rejects mismatched slice layouts" {
  let filter = @src.ScalableBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(32 + 12, 1U)
  bytes.unsafe_write_uint32_le(32 + 16, 16U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable counting serialization rejects zero slice counts" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 0U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects too many slices" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 65U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects zero initial capacity" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 0U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects negative insertion counts" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 0xFFFFFFFFU)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects truncated metadata" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes()
  @src.ScalableCountingBloomFilter::from_bytes(
    bytes.exact_view(end=40).to_owned(),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects truncated slice headers" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01).to_bytes()
  @src.ScalableCountingBloomFilter::from_bytes(
    bytes.exact_view(end=32).to_owned(),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects zero occurrences" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(32 + 20, 0U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects duplicate metadata" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("first")
  filter.insert("second")
  let bytes = filter.to_bytes().to_fixedarray()
  for i = 0; i < 16; i = i + 1 {
    bytes[32 + 24 + i] = bytes[32 + i]
  }
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic scalable counting serialization rejects mismatched slice layouts" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key")
  let bytes = filter.to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(56 + 4 + 12, 2U)
  bytes.unsafe_write_uint32_le(56 + 4 + 16, 16U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic compact counting serialization rejects negative insertion counts" {
  let bytes = @src.CompactCountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 0xFFFFFFFFU)
  @src.CompactCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}

///|
test "panic bloom insert_if_absent rejects count overflow" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  let filter = @src.BloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic counting bloom insert_if_absent rejects count overflow" {
  let bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  let filter = @src.CountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic blocked bloom filter rejects insertion count overflow" {
  let bytes = @src.BlockedBloomFilter::with_size(512, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  let filter = @src.BlockedBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  filter.insert("overflow")
}

///|
test "panic blocked bloom insert_if_absent rejects count overflow" {
  let bytes = @src.BlockedBloomFilter::with_size(512, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  let filter = @src.BlockedBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic blocked bloom merge rejects insertion count overflow" {
  let bytes = @src.BlockedBloomFilter::with_size(512, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  let left = @src.BlockedBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  let right = @src.BlockedBloomFilter::with_size(512, 1)
  right.insert("one")
  left.merge(right)
}

///|
test "panic cuckoo serialization rejects a zero eviction state" {
  let bytes = @src.CuckooFilter::with_size(4, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint64_le(24, 0UL)
  @src.CuckooFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "cuckoo serialization round trip preserves a usable eviction state" {
  let filter = @src.CuckooFilter::with_size(8, 2)
  assert_true(filter.insert_all(["a", "b", "c", "d"]))
  let restored = @src.CuckooFilter::from_bytes(filter.to_bytes())
  assert_true(restored.insert("e"))
  assert_true(restored.contains_all(["a", "b", "c", "d", "e"]))
  assert_eq(restored.count(), filter.count() + 1)
}

