///|
test "cuckoo filter holds the requested number of distinct keys" {
  let sizes : Array[Int32] = [10, 100, 1000, 10000]
  for expected_items in sizes {
    let filter = @src.CuckooFilter::new(expected_items)
    for i = 0; i < expected_items; i = i + 1 {
      if !filter.insert("key-" + i.to_string()) {
        abort(
          "cuckoo insert failed before expected capacity at " +
          i.to_string() +
          " of " +
          expected_items.to_string(),
        )
      }
    }
    for i = 0; i < expected_items; i = i + 1 {
      assert_true(filter.contains("key-" + i.to_string()))
    }
  }
}

///|
test "counting remove_all reports failure but keeps removing later keys" {
  let filter = @src.CountingBloomFilter::with_size(4096, 4)
  let keys = ["a", "b", "c"]
  filter.insert_all(keys)
  let batch = ["a", "missing", "b"]
  assert_false(filter.remove_all(batch))
  assert_false(filter.contains("a"))
  assert_false(filter.contains("b"))
  assert_true(filter.contains("c"))
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo remove_all reports failure but keeps removing later keys" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  let keys = ["a", "b", "c"]
  assert_true(filter.insert_all(keys))
  let batch = ["a", "missing", "b"]
  assert_false(filter.remove_all(batch))
  assert_false(filter.contains("a"))
  assert_false(filter.contains("b"))
  assert_true(filter.contains("c"))
  assert_eq(filter.count(), 1)
}

///|
test "panic constructors reject sizes beyond the supported limits" {
  @src.BloomFilter::with_size(2147483585, 1) |> ignore
}

///|
test "panic counting constructor rejects sizes beyond the supported limits" {
  @src.CountingBloomFilter::with_size(2147483585, 1) |> ignore
}

///|
test "panic cuckoo rejects oversized expected items" {
  @src.CuckooFilter::new(536870913) |> ignore
}

///|
test "panic cuckoo rejects oversized bucket counts" {
  @src.CuckooFilter::with_size(1073741825, 1) |> ignore
}

///|
test "panic cuckoo rejects oversized bucket sizes" {
  @src.CuckooFilter::with_size(2, 1073741824) |> ignore
}

///|
test "panic serialization rejects an unsupported version" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  bytes[5] = b'\x02'
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic serialization rejects negative insertion counts" {
  let bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 0xFFFFFFFFU)
  @src.BloomFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "panic serialization rejects an invalid counting hash count" {
  let bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  bytes.unsafe_write_uint32_le(12, 0U)
  @src.CountingBloomFilter::from_bytes(Bytes::from_array(bytes.exact_view()))
  |> ignore
}

///|
test "panic serialization rejects cuckoo counts above capacity" {
  let bytes = @src.CuckooFilter::with_size(4, 1).to_bytes().to_fixedarray()
  bytes.unsafe_write_uint32_le(16, 5U)
  @src.CuckooFilter::from_bytes(Bytes::from_array(bytes.exact_view())) |> ignore
}

///|
test "concurrent filters serialize and restore while locked" {
  let bloom = @src.ConcurrentBloomFilter::with_size(1024, 4)
  bloom.insert("bloom")
  let restored_bloom = @src.ConcurrentBloomFilter::from_bytes(bloom.to_bytes())
  assert_true(restored_bloom.contains("bloom"))
  assert_eq(restored_bloom.count(), 1)
  let counting = @src.ConcurrentCountingBloomFilter::with_size(512, 4)
  counting.insert("counting")
  let restored_counting = @src.ConcurrentCountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_true(restored_counting.contains("counting"))
  assert_true(restored_counting.remove("counting"))
  let cuckoo = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_true(cuckoo.insert("cuckoo"))
  let restored_cuckoo = @src.ConcurrentCuckooFilter::from_bytes(
    cuckoo.to_bytes(),
  )
  assert_true(restored_cuckoo.contains("cuckoo"))
  assert_true(restored_cuckoo.remove("cuckoo"))
}
