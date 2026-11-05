///|
/// Serialization boundary conditions: empty input and truncated byte
/// sequences must panic for every filter type.

///|
test "panic bloom from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.BloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic counting from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.CountingBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic compact counting from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.CompactCountingBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic blocked bloom from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.BlockedBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic cuckoo from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.CuckooFilter::from_bytes(empty) |> ignore
}

///|
test "panic scalable bloom from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ScalableBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic scalable counting from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ScalableCountingBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic bloom from_bytes rejects truncated header" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes()
  @src.BloomFilter::from_bytes(bytes.exact_view(end=4).to_owned()) |> ignore
}

///|
test "panic counting from_bytes rejects truncated header" {
  let bytes = @src.CountingBloomFilter::with_size(16, 1).to_bytes()
  @src.CountingBloomFilter::from_bytes(bytes.exact_view(end=4).to_owned()) |> ignore
}

///|
test "panic compact counting from_bytes rejects truncated header" {
  let bytes = @src.CompactCountingBloomFilter::with_size(16, 1).to_bytes()
  @src.CompactCountingBloomFilter::from_bytes(bytes.exact_view(end=4).to_owned()) |> ignore
}

///|
test "panic blocked bloom from_bytes rejects truncated header" {
  let bytes = @src.BlockedBloomFilter::with_size(512, 1).to_bytes()
  @src.BlockedBloomFilter::from_bytes(bytes.exact_view(end=4).to_owned()) |> ignore
}

///|
test "panic cuckoo from_bytes rejects truncated header" {
  let bytes = @src.CuckooFilter::with_size(4, 1).to_bytes()
  @src.CuckooFilter::from_bytes(bytes.exact_view(end=4).to_owned()) |> ignore
}

///|
test "panic scalable bloom from_bytes rejects truncated body" {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes()
  @src.ScalableBloomFilter::from_bytes(bytes.exact_view(end=20).to_owned()) |> ignore
}

///|
test "panic scalable counting from_bytes rejects truncated body" {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01).to_bytes()
  @src.ScalableCountingBloomFilter::from_bytes(bytes.exact_view(end=20).to_owned()) |> ignore
}

///|
test "panic concurrent bloom from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ConcurrentBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic concurrent counting from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ConcurrentCountingBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic concurrent compact counting from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ConcurrentCompactCountingBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic concurrent blocked bloom from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ConcurrentBlockedBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic concurrent cuckoo from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ConcurrentCuckooFilter::from_bytes(empty) |> ignore
}

///|
test "panic concurrent scalable bloom from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ConcurrentScalableBloomFilter::from_bytes(empty) |> ignore
}

///|
test "panic concurrent scalable counting from_bytes rejects empty data" {
  let empty : Bytes = Bytes::from_array([])
  @src.ConcurrentScalableCountingBloomFilter::from_bytes(empty) |> ignore
}
