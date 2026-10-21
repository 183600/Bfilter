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
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("seed")
  let bytes = filter.to_bytes().to_fixedarray()
  let view = Bytes::from_array(bytes.exact_view())
  let entry_count = view.unsafe_read_uint32_le(28).reinterpret_as_int()
  let slices_offset = 32 + entry_count * 24
  let slice_header = slices_offset + 4
  bytes.unsafe_write_uint32_le(12, 2147483647U)
  bytes.unsafe_write_uint32_le(52, 2147483647U)
  bytes.unsafe_write_uint32_le(slice_header + 16, 2147483647U)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
}

///|
test "scalable counting max inserted fixture is valid" {
  let filter = max_inserted_scalable_counting()
  assert_eq(filter.count(), 2147483647)
  assert_eq(filter.tracked_key_count(), 1)
}

///|
test "scalable counting same-slice merge keeps the larger max multiplicity" {
  let left = max_inserted_scalable_counting()
  let right = @src.ScalableCountingBloomFilter::new(4, 0.01)
  right.insert("seed")
  left.merge(right)
  assert_eq(left.count_of("seed"), 2147483647)
  assert_eq(left.count(), 2147483647)
  assert_eq(left.tracked_key_count(), 1)
  let restored = @src.ScalableCountingBloomFilter::from_bytes(left.to_bytes())
  assert_eq(restored.count(), 2147483647)
  assert_eq(restored.count_of("seed"), 2147483647)
  assert_eq(restored.tracked_key_count(), 1)
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
