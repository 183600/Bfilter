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
test "panic compact counting merge rejects count-only source overflow" {
  let left = max_inserted_compact_counting()
  let bytes = @src.CompactCountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 1U)
  let right = @src.CompactCountingBloomFilter::from_bytes(
    Bytes::from_array(bytes.exact_view()),
  )
  assert_eq(right.count(), 1)
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

///|
fn max_inserted_bloom() -> @src.BloomFilter {
  let bytes = @src.BloomFilter::with_size(64, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
}

///|
test "panic bloom insert rejects count overflow" {
  let filter = max_inserted_bloom()
  filter.insert("overflow")
}

///|
test "panic bloom insert_if_absent rejects count overflow" {
  let filter = max_inserted_bloom()
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic bloom merge rejects count overflow" {
  let left = max_inserted_bloom()
  let right = @src.BloomFilter::with_size(64, 1)
  right.insert("one")
  left.merge(right)
}

///|
/// A full power-of-two filter with a wide probe walk takes the full-filter
/// shortcut; that path also increments the counter and must stay guarded.
fn max_inserted_full_bloom() -> @src.BloomFilter {
  let bytes = @src.BloomFilter::with_size(128, 1)
    .to_bytes()
    .to_fixedarray()
  // A wide hash count makes the shortcut cheaper than the 128-position walk.
  bytes.unsafe_write_uint32_le(12, 160U)
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  // Fill both backing words so `all_bits_set()` selects the shortcut.
  for i = 20; i < 36; i = i + 1 {
    bytes[i] = b'\xFF'
  }
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
}

///|
test "full max-inserted bloom fixture is valid" {
  let filter = max_inserted_full_bloom()
  assert_eq(filter.count(), 2147483647)
  assert_eq(filter.set_bit_count(), filter.bit_count())
}

///|
test "panic bloom insert rejects count overflow on full filter shortcut" {
  let filter = max_inserted_full_bloom()
  filter.insert("overflow")
}

///|
fn max_inserted_counting() -> @src.CountingBloomFilter {
  let bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  @src.CountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
}

///|
test "panic counting insert rejects count overflow" {
  let filter = max_inserted_counting()
  filter.insert("overflow")
}

///|
test "panic counting insert_if_absent rejects count overflow" {
  let filter = max_inserted_counting()
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic counting merge rejects count overflow" {
  let left = max_inserted_counting()
  let right = @src.CountingBloomFilter::with_size(16, 1)
  right.insert("one")
  left.merge(right)
}

///|
fn max_inserted_blocked_bloom() -> @src.BlockedBloomFilter {
  let bytes = @src.BlockedBloomFilter::with_size(64, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 2147483647U)
  @src.BlockedBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
}

///|
test "panic blocked bloom insert rejects count overflow" {
  let filter = max_inserted_blocked_bloom()
  filter.insert("overflow")
}

///|
test "panic blocked bloom insert_if_absent rejects count overflow" {
  let filter = max_inserted_blocked_bloom()
  filter.insert_if_absent("overflow") |> ignore
}

///|
test "panic blocked bloom merge rejects count overflow" {
  let left = max_inserted_blocked_bloom()
  let right = @src.BlockedBloomFilter::with_size(64, 1)
  right.insert("one")
  left.merge(right)
}
