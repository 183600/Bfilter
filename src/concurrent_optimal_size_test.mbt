///|
test "concurrent filters expose allocation-free optimal sizes" {
  let (bloom_bits, bloom_hashes) = @src.ConcurrentBloomFilter::optimal_size(
    10_000, 0.01,
  )
  let bloom = @src.ConcurrentBloomFilter::new(10_000, 0.01)
  assert_eq(bloom_bits, bloom.bit_count())
  assert_eq(bloom_hashes, bloom.hash_count())
  assert_eq(
    (bloom_bits, bloom_hashes),
    @src.BloomFilter::optimal_size(10_000, 0.01),
  )

  let (blocked_bits, blocked_hashes) = @src.ConcurrentBlockedBloomFilter::optimal_size(
    10_000, 0.01,
  )
  let blocked = @src.ConcurrentBlockedBloomFilter::new(10_000, 0.01)
  assert_eq(blocked_bits, blocked.bit_count())
  assert_eq(blocked_hashes, blocked.hash_count())
  assert_eq(
    (blocked_bits, blocked_hashes),
    @src.BlockedBloomFilter::optimal_size(10_000, 0.01),
  )

  let (counting_slots, counting_hashes) = @src.ConcurrentCountingBloomFilter::optimal_size(
    10_000, 0.01,
  )
  let counting = @src.ConcurrentCountingBloomFilter::new(10_000, 0.01)
  assert_eq(counting_slots, counting.slot_count())
  assert_eq(counting_hashes, counting.hash_count())
  assert_eq(
    (counting_slots, counting_hashes),
    @src.CountingBloomFilter::optimal_size(10_000, 0.01),
  )

  let (compact_slots, compact_hashes) = @src.ConcurrentCompactCountingBloomFilter::optimal_size(
    10_000, 0.01,
  )
  let compact = @src.ConcurrentCompactCountingBloomFilter::new(10_000, 0.01)
  assert_eq(compact_slots, compact.slot_count())
  assert_eq(compact_hashes, compact.hash_count())
  assert_eq(
    (compact_slots, compact_hashes),
    @src.CompactCountingBloomFilter::optimal_size(10_000, 0.01),
  )

  let (buckets, bucket_size) = @src.ConcurrentCuckooFilter::optimal_size(10_000)
  let cuckoo = @src.ConcurrentCuckooFilter::new(10_000)
  assert_eq(buckets, cuckoo.bucket_count())
  assert_eq(bucket_size, cuckoo.bucket_size())
  assert_eq((buckets, bucket_size), @src.CuckooFilter::optimal_size(10_000))
}

///|
test "panic concurrent optimal size rejects invalid arguments" {
  @src.ConcurrentBloomFilter::optimal_size(0, 0.01) |> ignore
}

///|
test "panic concurrent bloom optimal size rejects not-a-number rate" {
  @src.ConcurrentBloomFilter::optimal_size(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent bloom optimal size rejects infinity rate" {
  @src.ConcurrentBloomFilter::optimal_size(10, @double.infinity) |> ignore
}

///|
test "panic concurrent bloom optimal size rejects negative infinity rate" {
  @src.ConcurrentBloomFilter::optimal_size(10, @double.neg_infinity) |> ignore
}

///|
test "panic concurrent blocked bloom optimal size rejects not-a-number rate" {
  @src.ConcurrentBlockedBloomFilter::optimal_size(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent counting optimal size rejects not-a-number rate" {
  @src.ConcurrentCountingBloomFilter::optimal_size(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent compact counting optimal size rejects not-a-number rate" {
  @src.ConcurrentCompactCountingBloomFilter::optimal_size(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent cuckoo optimal size rejects invalid capacity" {
  @src.ConcurrentCuckooFilter::optimal_size(0) |> ignore
}

///|
test "panic concurrent scalable bloom optimal size rejects not-a-number rate" {
  @src.ConcurrentScalableBloomFilter::optimal_size(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent scalable bloom optimal size rejects infinity rate" {
  @src.ConcurrentScalableBloomFilter::optimal_size(10, @double.infinity) |> ignore
}

///|
test "panic concurrent scalable counting optimal size rejects not-a-number rate" {
  @src.ConcurrentScalableCountingBloomFilter::optimal_size(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent scalable counting optimal size rejects infinity rate" {
  @src.ConcurrentScalableCountingBloomFilter::optimal_size(10, @double.infinity) |> ignore
}

///|
test "panic concurrent bloom new rejects not-a-number rate" {
  @src.ConcurrentBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent bloom new rejects infinity rate" {
  @src.ConcurrentBloomFilter::new(10, @double.infinity) |> ignore
}

///|
test "panic concurrent blocked bloom new rejects not-a-number rate" {
  @src.ConcurrentBlockedBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent counting new rejects not-a-number rate" {
  @src.ConcurrentCountingBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent compact counting new rejects not-a-number rate" {
  @src.ConcurrentCompactCountingBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent scalable bloom new rejects not-a-number rate" {
  @src.ConcurrentScalableBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent scalable counting new rejects not-a-number rate" {
  @src.ConcurrentScalableCountingBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic concurrent bloom with_size rejects zero hash count" {
  @src.ConcurrentBloomFilter::with_size(64, 0) |> ignore
}

///|
test "panic concurrent blocked bloom with_size rejects zero hash count" {
  @src.ConcurrentBlockedBloomFilter::with_size(512, 0) |> ignore
}

///|
test "panic concurrent counting with_size rejects zero hash count" {
  @src.ConcurrentCountingBloomFilter::with_size(16, 0) |> ignore
}

///|
test "panic concurrent compact counting with_size rejects zero hash count" {
  @src.ConcurrentCompactCountingBloomFilter::with_size(16, 0) |> ignore
}

///|
test "panic concurrent cuckoo with_size rejects zero bucket size" {
  @src.ConcurrentCuckooFilter::with_size(4, 0) |> ignore
}

///|
test "panic concurrent cuckoo with_size rejects too many buckets" {
  @src.ConcurrentCuckooFilter::with_size(1073741825, 1) |> ignore
}

///|
test "panic concurrent cuckoo with_size checks capacity after rounding" {
  @src.ConcurrentCuckooFilter::with_size(536870913, 2) |> ignore
  @src.ConcurrentCuckooFilter::with_size(1073741823, 2) |> ignore
}

///|
test "panic concurrent scalable bloom new rejects invalid args" {
  @src.ConcurrentScalableBloomFilter::new(0, 0.01) |> ignore
}

///|
test "panic concurrent scalable counting new rejects invalid args" {
  @src.ConcurrentScalableCountingBloomFilter::new(0, 0.01) |> ignore
}

///|
test "panic concurrent bloom with_size rejects oversized bit count" {
  @src.ConcurrentBloomFilter::with_size(2147483585, 1) |> ignore
}

///|
test "panic concurrent blocked bloom with_size rejects oversized bit count" {
  @src.ConcurrentBlockedBloomFilter::with_size(2147483137, 1) |> ignore
}

///|
test "panic concurrent counting with_size rejects oversized slot count" {
  @src.ConcurrentCountingBloomFilter::with_size(1073741809, 1) |> ignore
}

///|
test "panic concurrent compact counting with_size rejects oversized slot count" {
  @src.ConcurrentCompactCountingBloomFilter::with_size(1073741809, 1) |> ignore
}

///|
test "panic concurrent blocked bloom new rejects invalid rate" {
  @src.ConcurrentBlockedBloomFilter::new(10, 1.0) |> ignore
}

///|
test "panic concurrent counting new rejects invalid rate" {
  @src.ConcurrentCountingBloomFilter::new(10, 1.0) |> ignore
}

///|
test "panic concurrent compact counting new rejects invalid rate" {
  @src.ConcurrentCompactCountingBloomFilter::new(10, 1.0) |> ignore
}

///|
test "panic concurrent scalable bloom new rejects invalid rate" {
  @src.ConcurrentScalableBloomFilter::new(10, 1.0) |> ignore
}

///|
test "panic concurrent scalable counting new rejects invalid rate" {
  @src.ConcurrentScalableCountingBloomFilter::new(10, 1.0) |> ignore
}
