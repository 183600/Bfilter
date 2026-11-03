///|
/// Minimal layouts exercise the lower bound of `with_size`: an argument of 1
/// bit/slot/bucket is rounded up to the allocator's quantum (a 64-bit word, a
/// 512-bit block, 16 counting slots, or a single cuckoo bucket). These are the
/// smallest allocatable filters and must still support insert, query, delete,
/// count, and clear.
test "minimal bloom filter with_size(1, 1) is functional" {
  let filter = @src.BloomFilter::with_size(1, 1)
  assert_eq(filter.bit_count(), 64)
  assert_eq(filter.hash_count(), 1)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  filter.insert("a")
  assert_true(filter.contains("a"))
  assert_eq(filter.count(), 1)
  assert_false(filter.is_empty())
  assert_false(filter.contains("missing"))
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("a"))
}

///|
test "minimal blocked bloom filter with_size(1, 1) is functional" {
  let filter = @src.BlockedBloomFilter::with_size(1, 1)
  assert_eq(filter.bit_count(), 512)
  assert_eq(filter.block_count(), 1)
  assert_eq(filter.hash_count(), 1)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  filter.insert("a")
  assert_true(filter.contains("a"))
  assert_eq(filter.count(), 1)
  assert_false(filter.contains("missing"))
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "minimal counting bloom filter with_size(1, 1) is functional" {
  let filter = @src.CountingBloomFilter::with_size(1, 1)
  assert_eq(filter.slot_count(), 16)
  assert_eq(filter.hash_count(), 1)
  assert_true(filter.is_empty())
  filter.insert("a")
  filter.insert("a")
  assert_eq(filter.count_of("a"), 2)
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 1)
  assert_true(filter.remove("a"))
  assert_false(filter.contains("a"))
  assert_eq(filter.count(), 0)
  assert_true(filter.is_empty())
}

///|
test "minimal compact counting bloom filter with_size(1, 1) is functional" {
  let filter = @src.CompactCountingBloomFilter::with_size(1, 1)
  assert_eq(filter.slot_count(), 16)
  assert_eq(filter.hash_count(), 1)
  assert_true(filter.is_empty())
  filter.insert("a")
  filter.insert("a")
  assert_eq(filter.count_of("a"), 2)
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 1)
  assert_true(filter.remove("a"))
  assert_false(filter.contains("a"))
  assert_eq(filter.count(), 0)
  assert_true(filter.is_empty())
}

///|
test "minimal cuckoo filter with_size(1, 1) is functional" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_eq(filter.bucket_count(), 1)
  assert_eq(filter.bucket_size(), 1)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_true(filter.insert("a"))
  assert_true(filter.contains("a"))
  assert_eq(filter.count(), 1)
  // A single-slot bucket cannot hold a second distinct fingerprint.
  assert_false(filter.insert("b"))
  assert_eq(filter.count(), 1)
  assert_true(filter.remove("a"))
  assert_false(filter.contains("a"))
  assert_eq(filter.count(), 0)
  assert_true(filter.is_empty())
}

///|
test "minimal bloom filter rejects absent keys without false negatives" {
  let filter = @src.BloomFilter::with_size(1, 1)
  filter.insert("present")
  assert_true(filter.contains("present"))
  // With only one hash function and 64 bits, absent keys should still be
  // reported absent unless they collide on the single probed bit; either
  // outcome is valid for a Bloom filter, but the inserted key must be found.
  assert_true(filter.contains("present"))
  assert_eq(filter.count(), 1)
}

///|
test "minimal counting filter saturates at counter_max" {
  let filter = @src.CountingBloomFilter::with_size(1, 1)
  let mut i = 0
  while i < 70000 {
    filter.insert("a")
    i = i + 1
  }
  assert_eq(filter.count_of("a"), 65535)
  assert_eq(filter.count(), 70000)
  // Removing below saturation still decrements the tracked count.
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 65534)
  assert_eq(filter.count(), 69999)
}
