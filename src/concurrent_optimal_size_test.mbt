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

  let (blocked_bits, blocked_hashes) =
    @src.ConcurrentBlockedBloomFilter::optimal_size(10_000, 0.01)
  let blocked = @src.ConcurrentBlockedBloomFilter::new(10_000, 0.01)
  assert_eq(blocked_bits, blocked.bit_count())
  assert_eq(blocked_hashes, blocked.hash_count())
  assert_eq(
    (blocked_bits, blocked_hashes),
    @src.BlockedBloomFilter::optimal_size(10_000, 0.01),
  )

  let (counting_slots, counting_hashes) =
    @src.ConcurrentCountingBloomFilter::optimal_size(10_000, 0.01)
  let counting = @src.ConcurrentCountingBloomFilter::new(10_000, 0.01)
  assert_eq(counting_slots, counting.slot_count())
  assert_eq(counting_hashes, counting.hash_count())
  assert_eq(
    (counting_slots, counting_hashes),
    @src.CountingBloomFilter::optimal_size(10_000, 0.01),
  )

  let (compact_slots, compact_hashes) =
    @src.ConcurrentCompactCountingBloomFilter::optimal_size(10_000, 0.01)
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
