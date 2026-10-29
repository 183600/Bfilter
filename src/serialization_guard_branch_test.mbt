///|
test "panic scalable counting serialization rejects a zero occurrence count" {
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
test "panic counting merge rejects insertion count overflow" {
  let left_source = @src.CountingBloomFilter::with_size(16, 1)
  left_source.insert("left")
  let left_bytes = left_source.to_bytes().to_fixedarray()
  left_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let right_source = @src.CountingBloomFilter::with_size(16, 1)
  right_source.insert("right")
  let right_bytes = right_source.to_bytes().to_fixedarray()
  right_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let left = @src.CountingBloomFilter::from_bytes(
    Bytes::from_array(left_bytes.exact_view()),
  )
  let right = @src.CountingBloomFilter::from_bytes(
    Bytes::from_array(right_bytes.exact_view()),
  )
  left.merge(right)
}
