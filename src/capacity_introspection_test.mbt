///|
test "counting filters expose their saturation limit" {
  assert_eq(@src.CountingBloomFilter::counter_max(), 65535)
  assert_eq(@src.ConcurrentCountingBloomFilter::counter_max(), 65535)
  assert_eq(@src.ScalableCountingBloomFilter::counter_max(), 65535)
  assert_eq(@src.ConcurrentScalableCountingBloomFilter::counter_max(), 65535)
  assert_eq(@src.CompactCountingBloomFilter::counter_max(), 15)
  assert_eq(@src.ConcurrentCompactCountingBloomFilter::counter_max(), 15)
}

///|
test "counting filter multiplicity stops at the exposed counter limit" {
  let filter = @src.CountingBloomFilter::with_size(16, 1)
  for i = 0; i < @src.CountingBloomFilter::counter_max() + 1; i = i + 1 {
    filter.insert("saturated")
  }
  assert_eq(
    filter.count_of("saturated"),
    @src.CountingBloomFilter::counter_max(),
  )
  assert_eq(filter.count(), @src.CountingBloomFilter::counter_max() + 1)
}

///|
test "cuckoo filter reports remaining capacity and fullness" {
  let filter = @src.CuckooFilter::with_size(4, 2)
  assert_eq(filter.capacity(), 8)
  assert_eq(filter.remaining_capacity(), 8)
  assert_false(filter.is_full())
  assert_true(filter.insert("first"))
  assert_eq(filter.remaining_capacity(), 7)
  assert_false(filter.is_full())
  assert_true(filter.remove("first"))
  assert_eq(filter.remaining_capacity(), 8)

  let tiny = @src.CuckooFilter::with_size(1, 1)
  assert_true(tiny.insert("only"))
  assert_true(tiny.is_full())
  assert_eq(tiny.remaining_capacity(), 0)
  assert_false(tiny.insert("second"))
  let restored = @src.CuckooFilter::from_bytes(tiny.to_bytes())
  assert_true(restored.is_full())
  assert_eq(restored.remaining_capacity(), 0)
  assert_true(tiny.remove("only"))
  assert_false(tiny.is_full())
  assert_eq(tiny.remaining_capacity(), 1)
}

///|
test "concurrent cuckoo filter reports fullness under the lock" {
  let filter = @src.ConcurrentCuckooFilter::with_size(1, 1)
  assert_eq(filter.capacity(), 1)
  assert_eq(filter.remaining_capacity(), 1)
  assert_false(filter.is_full())
  assert_true(filter.insert("only"))
  assert_true(filter.is_full())
  assert_eq(filter.remaining_capacity(), 0)
  assert_false(filter.insert("second"))
  assert_true(filter.remove("only"))
  assert_false(filter.is_full())
  assert_eq(filter.remaining_capacity(), 1)
}
