///|
test "fixed-size filters size layouts for the smallest positive rate" {
  let rate = @double.min_positive
  let bloom = @src.BloomFilter::new(1, rate)
  let (bloom_bits, bloom_hashes) = @src.BloomFilter::optimal_size(1, rate)
  assert_eq(bloom.bit_count(), bloom_bits)
  assert_eq(bloom.hash_count(), bloom_hashes)
  assert_true(bloom_bits >= 64)
  assert_true(bloom_hashes > 1)

  let counting = @src.CountingBloomFilter::new(1, rate)
  let (counting_slots, counting_hashes) = @src.CountingBloomFilter::optimal_size(
    1, rate,
  )
  assert_eq(counting.slot_count(), counting_slots)
  assert_eq(counting.hash_count(), counting_hashes)
  assert_eq(counting_slots % 16, 0)

  let compact = @src.CompactCountingBloomFilter::new(1, rate)
  let (compact_slots, compact_hashes) = @src.CompactCountingBloomFilter::optimal_size(
    1, rate,
  )
  assert_eq(compact.slot_count(), compact_slots)
  assert_eq(compact.hash_count(), compact_hashes)
  assert_eq(compact_slots, counting_slots)
  assert_eq(compact_hashes, counting_hashes)

  let blocked = @src.BlockedBloomFilter::new(1, rate)
  let (blocked_bits, blocked_hashes) = @src.BlockedBloomFilter::optimal_size(
    1, rate,
  )
  assert_eq(blocked.bit_count(), blocked_bits)
  assert_eq(blocked.hash_count(), blocked_hashes)
  assert_eq(blocked_bits % 512, 0)
}

///|
test "cuckoo optimal size accepts the largest supported capacity" {
  let expected = 536870912
  let (buckets, size) = @src.CuckooFilter::optimal_size(expected)
  assert_eq(buckets, 268435456)
  assert_eq(size, 4)
  assert_true(buckets.to_int64() * size.to_int64() >= expected.to_int64())
}

///|
test "panic bloom filter rejects a not-a-number false positive rate" {
  @src.BloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic blocked bloom filter rejects a not-a-number false positive rate" {
  @src.BlockedBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic counting filter rejects a not-a-number false positive rate" {
  @src.CountingBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic compact counting filter rejects a not-a-number false positive rate" {
  @src.CompactCountingBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic scalable bloom filter rejects a not-a-number false positive rate" {
  @src.ScalableBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic scalable counting filter rejects a not-a-number false positive rate" {
  @src.ScalableCountingBloomFilter::new(10, @double.not_a_number) |> ignore
}

///|
test "panic optimal size helpers reject infinite false positive rates" {
  @src.BloomFilter::optimal_size(10, @double.infinity) |> ignore
}

///|
test "panic counting optimal size rejects negative infinity rates" {
  @src.CountingBloomFilter::optimal_size(10, @double.neg_infinity) |> ignore
}

///|
test "scalable filters support subnormal rates while growing" {
  // Multiplying this rate by the slice policy factor underflows to zero once
  // the filter reaches its fourth slice, exercising the target-rate fallback.
  let rate = @double.min_positive / 1.0e15
  let bloom = @src.ScalableBloomFilter::new(1, rate)
  for i = 0; i < 8; i = i + 1 {
    bloom.insert("key-" + i.to_string())
  }
  assert_eq(bloom.slice_count(), 4)
  assert_eq(bloom.target_false_positive_rate(), rate)
  assert_true(bloom.contains("key-0"))
  assert_true(bloom.contains("key-7"))
  let bloom_restored = @src.ScalableBloomFilter::from_bytes(bloom.to_bytes())
  assert_eq(bloom_restored.slice_count(), 4)
  assert_true(bloom_restored.contains_all(["key-0", "key-7"]))

  let counting = @src.ScalableCountingBloomFilter::new(1, rate)
  for i = 0; i < 8; i = i + 1 {
    counting.insert("key-" + i.to_string())
  }
  counting.insert("key-0")
  assert_eq(counting.slice_count(), 4)
  assert_eq(counting.target_false_positive_rate(), rate)
  assert_eq(counting.count_of("key-0"), 2)
  assert_eq(counting.count_of("key-7"), 1)
  let counting_restored = @src.ScalableCountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_eq(counting_restored.slice_count(), 4)
  assert_eq(counting_restored.count_of("key-0"), 2)
  assert_true(counting_restored.remove("key-0"))
  assert_eq(counting_restored.count_of("key-0"), 1)
}
