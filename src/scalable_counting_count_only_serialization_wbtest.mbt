///|
test "scalable counting serializes count-only empty slices" {
  let filter = ScalableCountingBloomFilter::new(2, 0.01)
  filter.append_slice()
  // Count-only slices carry a conservative insertion count without any tracked
  // key or positive counter. Set-operation tests treat this state as a valid
  // empty filter, so serialization must round trip it as well.
  filter.slices[0].inserted = 2
  filter.slices[1].inserted = 3
  filter.inserted = 5
  assert_eq(filter.occupied_slot_count(), 0L)
  assert_eq(filter.tracked_key_count(), 0)

  let bytes = filter.to_bytes()
  let restored = ScalableCountingBloomFilter::from_bytes(bytes)
  assert_eq(restored.count(), 5)
  assert_eq(restored.tracked_key_count(), 0)
  assert_eq(restored.slice_count(), filter.slice_count())
  assert_eq(restored.occupied_slot_count(), 0L)
  assert_eq(restored.to_bytes(), bytes)
}

///|
fn drop_scalable_counting_metadata(data : Bytes) -> Bytes {
  let source = data.to_fixedarray()
  let view = Bytes::from_array(source.exact_view())
  let entry_count = view.unsafe_read_uint32_le(28).reinterpret_as_int()
  let metadata_bytes = entry_count * 24
  let result = FixedArray::make(
    source.length() - metadata_bytes,
    b'\x00',
  )
  for i = 0; i < 32; i = i + 1 {
    result[i] = source[i]
  }
  for i = 0; i < source.length() - 32 - metadata_bytes; i = i + 1 {
    result[32 + i] = source[32 + metadata_bytes + i]
  }
  result.unsafe_write_uint32_le(28, 0U)
  Bytes::from_array(result.exact_view())
}

///|
test "panic scalable counting serialization rejects lost metadata with counters" {
  let filter = ScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("tracked")
  assert_true(filter.occupied_slot_count() > 0L)
  // Removing the metadata from a filter with positive counters must still be
  // rejected; only the genuinely counter-free count-only form is accepted.
  ScalableCountingBloomFilter::from_bytes(
    drop_scalable_counting_metadata(filter.to_bytes()),
  )
  |> ignore
}

///|
test "scalable counting count-only filter stays serializable after insertion" {
  let filter = ScalableCountingBloomFilter::new(2, 0.01)
  filter.append_slice()
  filter.slices[0].inserted = 2
  filter.slices[1].inserted = 3
  filter.inserted = 5

  let restored = ScalableCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), 5)
  restored.insert("fresh")
  assert_eq(restored.count(), 6)
  assert_eq(restored.count_of("fresh"), 1)
  assert_true(restored.contains("fresh"))

  let restored_again = ScalableCountingBloomFilter::from_bytes(
    restored.to_bytes(),
  )
  assert_eq(restored_again.count(), 6)
  assert_eq(restored_again.tracked_key_count(), 1)
  assert_eq(restored_again.count_of("fresh"), 1)
  assert_true(restored_again.contains("fresh"))

  assert_true(restored_again.remove("fresh"))
  assert_eq(restored_again.count(), 5)
  assert_eq(restored_again.tracked_key_count(), 0)
  let empty_again = ScalableCountingBloomFilter::from_bytes(
    restored_again.to_bytes(),
  )
  assert_eq(empty_again.count(), 5)
  assert_eq(empty_again.tracked_key_count(), 0)
}
