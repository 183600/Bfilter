///|
test "panic bloom serialization rejects nonzero reserved header bytes" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  bytes[6] = b'\x01'
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic counting serialization rejects nonzero reserved header bytes" {
  let bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes[7] = b'\x01'
  @src.CountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic cuckoo serialization rejects nonzero reserved header bytes" {
  let bytes = @src.CuckooFilter::with_size(4, 1).to_bytes().to_fixedarray()
  bytes[6] = b'\x01'
  @src.CuckooFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic bloom serialization rejects trailing data" {
  let bytes = @src.BloomFilter::with_size(128, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 64U)
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic cuckoo serialization rejects a zero bucket size" {
  let bytes = @src.CuckooFilter::with_size(4, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 0U)
  @src.CuckooFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic cuckoo serialization rejects an oversized bucket size" {
  let bytes = @src.CuckooFilter::with_size(1, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 2147483628U)
  @src.CuckooFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}
