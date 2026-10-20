///|
test "bloom filter serialization round trip" {
  let filter = @src.BloomFilter::with_size(1024, 5)
  let keys = ["alpha", "beta", "gamma", "delta"]
  filter.insert_all(keys)
  filter.insert(42)
  let restored = @src.BloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.bit_count(), filter.bit_count())
  assert_eq(restored.hash_count(), filter.hash_count())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.set_bit_count(), filter.set_bit_count())
  assert_true(restored.contains_all(keys))
  assert_true(restored.contains(42))
  restored.insert("restored")
  assert_eq(filter.count(), 5)
  assert_eq(restored.count(), 6)
}

///|
test "counting filter serialization round trip" {
  let filter = @src.CountingBloomFilter::with_size(512, 4)
  filter.insert("duplicate")
  filter.insert("duplicate")
  filter.insert("other")
  let restored = @src.CountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.slot_count(), filter.slot_count())
  assert_eq(restored.hash_count(), filter.hash_count())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
  assert_true(restored.contains("duplicate"))
  assert_true(restored.remove("duplicate"))
  assert_true(restored.contains("duplicate"))
  assert_true(restored.remove("duplicate"))
  assert_false(restored.contains("duplicate"))
  assert_true(filter.contains("duplicate"))
  assert_eq(filter.count(), 3)
  assert_eq(restored.count(), 1)
}

///|
test "cuckoo filter serialization round trip" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  let keys = ["a", "b", "c", "d", "e"]
  assert_true(filter.insert_all(keys))
  let restored = @src.CuckooFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.bucket_count(), filter.bucket_count())
  assert_eq(restored.bucket_size(), filter.bucket_size())
  assert_eq(restored.count(), filter.count())
  assert_true(restored.contains_all(keys))
  assert_true(restored.remove("a"))
  assert_false(restored.contains("a"))
  assert_true(filter.contains("a"))
  assert_eq(filter.count(), 5)
  assert_eq(restored.count(), 4)
}

///|
test "serialization round trips empty filters" {
  let bloom = @src.BloomFilter::with_size(64, 1)
  let restored_bloom = @src.BloomFilter::from_bytes(bloom.to_bytes())
  assert_true(restored_bloom.is_empty())
  assert_eq(restored_bloom.bit_count(), 64)
  let counting = @src.CountingBloomFilter::with_size(16, 1)
  let restored_counting = @src.CountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_true(restored_counting.is_empty())
  assert_eq(restored_counting.slot_count(), 16)
  let cuckoo = @src.CuckooFilter::with_size(1, 1)
  let restored_cuckoo = @src.CuckooFilter::from_bytes(cuckoo.to_bytes())
  assert_true(restored_cuckoo.is_empty())
  assert_eq(restored_cuckoo.bucket_count(), 1)
}

///|
test "panic serialization rejects short data" {
  @src.BloomFilter::from_bytes(b"") |> ignore
}

///|
test "panic serialization rejects invalid magic" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  bytes[0] = b'\x00'
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic serialization rejects another filter type" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes()
  @src.CountingBloomFilter::from_bytes(bytes) |> ignore
}

///|
test "panic serialization rejects invalid bloom configuration" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 65U)
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic serialization rejects invalid counting configuration" {
  let bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 24U)
  @src.CountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic serialization rejects invalid cuckoo configuration" {
  let bytes = @src.CuckooFilter::with_size(4, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(8, 3U)
  @src.CuckooFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}
