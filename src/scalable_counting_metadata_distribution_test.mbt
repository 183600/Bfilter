///|
test "panic scalable counting serialization rejects misplaced metadata" {
  let filter = @src.ScalableCountingBloomFilter::new(1, 0.5)
  filter.insert("first")
  filter.insert("second")
  assert_eq(filter.slice_count(), 2)
  let data = filter.to_bytes().to_fixedarray()
  let view = Bytes::from_array(data.exact_view())
  let entry_count = view.unsafe_read_uint32_le(28).reinterpret_as_int()
  assert_eq(entry_count, 2)
  let metadata_offset = data.length() - entry_count * 24
  let mut moved = false
  for entry = 0; entry < entry_count; entry = entry + 1 {
    let slice_offset = metadata_offset + entry * 24 + 16
    if view.unsafe_read_uint32_le(slice_offset) == 1U {
      data.unsafe_write_uint32_le(slice_offset, 0U)
      moved = true
    }
  }
  assert_true(moved)
  @src.ScalableCountingBloomFilter::from_bytes(
    Bytes::from_array(data.exact_view()),
  )
  |> ignore
}
