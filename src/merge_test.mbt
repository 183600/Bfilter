///|
test "bloom filter merge updates the receiver in place" {
  let left = @src.BloomFilter::with_size(8192, 4)
  let right = @src.BloomFilter::with_size(8192, 4)
  left.insert("left")
  right.insert("right")
  right.insert("right-2")
  left.merge(right)
  assert_true(left.contains("left"))
  assert_true(left.contains("right"))
  assert_true(left.contains("right-2"))
  assert_eq(left.count(), 3)
  right.insert("later")
  assert_eq(left.count(), 3)
}

///|
test "panic bloom filter merge rejects insertion count overflow" {
  let left_bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  left_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let right_bytes = @src.BloomFilter::with_size(64, 1)
    .to_bytes()
    .to_fixedarray()
  right_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let left = @src.BloomFilter::from_bytes(
    Bytes::from_array(left_bytes.exact_view()),
  )
  let right = @src.BloomFilter::from_bytes(
    Bytes::from_array(right_bytes.exact_view()),
  )
  left.merge(right)
}

///|
test "counting bloom filter merge keeps counters and multiplicities" {
  let left = @src.CountingBloomFilter::with_size(8192, 4)
  let right = @src.CountingBloomFilter::with_size(8192, 4)
  left.insert("shared")
  left.insert("shared")
  right.insert("shared")
  right.insert("right")
  left.merge(right)
  assert_eq(left.count(), 4)
  assert_true(left.contains("shared"))
  assert_true(left.contains("right"))
  assert_true(left.remove("shared"))
  assert_true(left.contains("shared"))
  assert_true(left.remove("shared"))
  assert_false(left.contains("shared"))
}

///|
test "panic counting bloom filter merge rejects insertion count overflow" {
  let left_bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  left_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let right_bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  right_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let left = @src.CountingBloomFilter::from_bytes(
    Bytes::from_array(left_bytes.exact_view()),
  )
  let right = @src.CountingBloomFilter::from_bytes(
    Bytes::from_array(right_bytes.exact_view()),
  )
  left.merge(right)
}

///|
test "concurrent bloom filter merges a snapshot" {
  let left = @src.ConcurrentBloomFilter::with_size(8192, 4)
  let right = @src.BloomFilter::with_size(8192, 4)
  left.insert("left")
  right.insert("right")
  left.merge(right)
  assert_true(left.contains("left"))
  assert_true(left.contains("right"))
  assert_eq(left.count(), 2)
}

///|
test "concurrent counting filter merges a snapshot" {
  let left = @src.ConcurrentCountingBloomFilter::with_size(8192, 4)
  let right = @src.CountingBloomFilter::with_size(8192, 4)
  left.insert("left")
  right.insert("right")
  left.merge(right)
  assert_true(left.contains("left"))
  assert_true(left.contains("right"))
  assert_eq(left.count(), 2)
  assert_true(left.remove("right"))
  assert_false(left.contains("right"))
}

///|
test "panic bloom filter merge rejects incompatible sizes" {
  let left = @src.BloomFilter::with_size(64, 2)
  let right = @src.BloomFilter::with_size(128, 2)
  left.merge(right)
}

///|
test "panic counting bloom filter merge rejects incompatible hash counts" {
  let left = @src.CountingBloomFilter::with_size(16, 2)
  let right = @src.CountingBloomFilter::with_size(16, 3)
  left.merge(right)
}
