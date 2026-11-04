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

///|
test "panic concurrent bloom filter with_size rejects a zero bit count" {
  @src.ConcurrentBloomFilter::with_size(0, 1) |> ignore
}

///|
test "panic concurrent bloom filter with_size rejects a zero hash count" {
  @src.ConcurrentBloomFilter::with_size(64, 0) |> ignore
}

///|
test "panic concurrent bloom filter optimal_size validates inputs" {
  @src.ConcurrentBloomFilter::optimal_size(0, 0.01) |> ignore
  @src.ConcurrentBloomFilter::optimal_size(100, 0.0) |> ignore
  @src.ConcurrentBloomFilter::optimal_size(100, 1.0) |> ignore
}

///|
test "panic concurrent blocked bloom filter with_size rejects invalid sizes" {
  @src.ConcurrentBlockedBloomFilter::with_size(0, 1) |> ignore
  @src.ConcurrentBlockedBloomFilter::with_size(512, 0) |> ignore
}

///|
test "panic concurrent counting bloom filter with_size rejects invalid size" {
  @src.ConcurrentCountingBloomFilter::with_size(0, 1) |> ignore
  @src.ConcurrentCountingBloomFilter::with_size(16, 0) |> ignore
}

///|
test "panic concurrent compact counting bloom filter with_size rejects invalid size" {
  @src.ConcurrentCompactCountingBloomFilter::with_size(0, 1) |> ignore
  @src.ConcurrentCompactCountingBloomFilter::with_size(16, 0) |> ignore
}

///|
test "panic concurrent cuckoo filter with_size rejects invalid bucket count" {
  @src.ConcurrentCuckooFilter::with_size(0, 1) |> ignore
}

///|
test "panic concurrent cuckoo filter with_size rejects invalid bucket size" {
  @src.ConcurrentCuckooFilter::with_size(16, 0) |> ignore
}

///|
test "panic concurrent scalable bloom filter new rejects invalid inputs" {
  @src.ConcurrentScalableBloomFilter::new(0, 0.01) |> ignore
  @src.ConcurrentScalableBloomFilter::new(100, 0.0) |> ignore
  @src.ConcurrentScalableBloomFilter::new(100, 1.0) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter new rejects invalid inputs" {
  @src.ConcurrentScalableCountingBloomFilter::new(0, 0.01) |> ignore
  @src.ConcurrentScalableCountingBloomFilter::new(100, 0.0) |> ignore
  @src.ConcurrentScalableCountingBloomFilter::new(100, 1.0) |> ignore
}
