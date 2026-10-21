///|
fn max_inserted_compact_counting() -> @src.CompactCountingBloomFilter {
  let bytes = @src.CompactCountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  @src.CompactCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
}

///|
test "panic compact counting insert rejects count overflow" {
  let filter = max_inserted_compact_counting()
  filter.insert("overflow")
}

///|
test "panic compact counting insert_if_absent rejects count overflow" {
  let filter = max_inserted_compact_counting()
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic compact counting merge rejects count overflow" {
  let left = max_inserted_compact_counting()
  let right = @src.CompactCountingBloomFilter::with_size(16, 1)
  right.insert("one")
  left.merge(right)
}

///|
fn max_inserted_scalable_bloom() -> @src.ScalableBloomFilter {
  let bytes = @src.ScalableBloomFilter::new(4, 0.01).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 2147483647U)
  bytes.unsafe_write_uint32_le(48, 2147483647U)
  @src.ScalableBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
}

///|
test "panic scalable bloom insert rejects count overflow" {
  let filter = max_inserted_scalable_bloom()
  filter.insert("overflow")
}

///|
test "panic scalable bloom insert_if_absent rejects count overflow" {
  let filter = max_inserted_scalable_bloom()
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic scalable bloom merge rejects count overflow" {
  let left = max_inserted_scalable_bloom()
  let right = @src.ScalableBloomFilter::new(4, 0.01)
  right.insert("one")
  left.merge(right)
}

///|
fn max_inserted_scalable_counting() -> @src.ScalableCountingBloomFilter {
  let bytes = @src.ScalableCountingBloomFilter::new(4, 0.01)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 2147483647U)
  bytes.unsafe_write_uint32_le(52, 2147483647U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
}

///|
test "panic scalable counting insert rejects count overflow" {
  let filter = max_inserted_scalable_counting()
  filter.insert("overflow")
}

///|
test "panic scalable counting insert_if_absent rejects count overflow" {
  let filter = max_inserted_scalable_counting()
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic scalable counting merge rejects count overflow" {
  let left = max_inserted_scalable_counting()
  let right = @src.ScalableCountingBloomFilter::new(4, 0.01)
  right.insert("one")
  left.merge(right)
}
