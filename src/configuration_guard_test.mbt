///|
test "panic bloom filter with_size rejects a zero hash count" {
  @src.BloomFilter::with_size(64, 0) |> ignore
}

///|
test "panic blocked bloom filter with_size rejects a zero hash count" {
  @src.BlockedBloomFilter::with_size(512, 0) |> ignore
}

///|
test "panic counting filter with_size rejects a zero hash count" {
  @src.CountingBloomFilter::with_size(16, 0) |> ignore
}

///|
test "panic compact counting filter with_size rejects a zero hash count" {
  @src.CompactCountingBloomFilter::with_size(16, 0) |> ignore
}

///|
test "panic bloom serialization rejects a zero hash count" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 0U)
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic scalable bloom serialization rejects a zero slice hash count" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(32 + 12, 0U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic scalable counting serialization rejects a zero slice hash count" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(32 + 4 + 12, 0U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  |> ignore
}
