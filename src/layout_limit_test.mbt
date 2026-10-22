///|
test "panic bloom family with_size rejects sizes just past the limit" {
  @src.BloomFilter::with_size(2147483585, 1) |> ignore
}

///|
test "panic blocked bloom with_size rejects sizes just past the limit" {
  @src.BlockedBloomFilter::with_size(2147483137, 1) |> ignore
}

///|
test "panic counting family with_size rejects slots just past the limit" {
  @src.CountingBloomFilter::with_size(1073741809, 1) |> ignore
}

///|
test "panic compact counting with_size rejects slots just past the limit" {
  @src.CompactCountingBloomFilter::with_size(1073741809, 1) |> ignore
}

///|
test "panic cuckoo with_size rejects too many buckets" {
  @src.CuckooFilter::with_size(1073741825, 1) |> ignore
}

///|
test "panic cuckoo optimal size rejects one item past the limit" {
  @src.CuckooFilter::optimal_size(536870913) |> ignore
}

///|
test "fixed-size filters size the maximum expected count with a near-one rate" {
  // A rate close to one keeps the required bit and slot counts tiny even for
  // the largest accepted expected-item count, so this exercises the sizing
  // arithmetic without allocating a large filter.
  let expected = 2147483647
  let rate = 0.999999999
  let bloom = @src.BloomFilter::new(expected, rate)
  assert_eq(bloom.bit_count(), @src.BloomFilter::optimal_size(expected, rate).0)
  assert_eq(bloom.hash_count(), @src.BloomFilter::optimal_size(expected, rate).1)
  assert_true(bloom.bit_count() >= 64)

  let counting = @src.CountingBloomFilter::new(expected, rate)
  let counting_layout = @src.CountingBloomFilter::optimal_size(expected, rate)
  assert_eq(counting.slot_count(), counting_layout.0)
  assert_eq(counting.hash_count(), counting_layout.1)
  assert_eq(counting.slot_count() % 16, 0)

  let compact = @src.CompactCountingBloomFilter::new(expected, rate)
  assert_eq(compact.slot_count(), counting.slot_count())
  assert_eq(compact.hash_count(), counting.hash_count())

  let blocked = @src.BlockedBloomFilter::new(expected, rate)
  let blocked_layout = @src.BlockedBloomFilter::optimal_size(expected, rate)
  assert_eq(blocked.bit_count(), blocked_layout.0)
  assert_eq(blocked.hash_count(), blocked_layout.1)
  assert_eq(blocked.bit_count() % 512, 0)
}
