///|
test "concurrent bloom filter serialization round trip" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 5)
  let keys = ["alpha", "beta", "gamma", "delta"]
  filter.insert_all(keys)
  filter.insert(42)
  let restored = @src.ConcurrentBloomFilter::from_bytes(filter.to_bytes())
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
test "concurrent bloom filter serialization round trips empty filters" {
  let filter = @src.ConcurrentBloomFilter::with_size(64, 1)
  let restored = @src.ConcurrentBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.bit_count(), 64)
}

///|
test "concurrent counting filter serialization round trip" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(512, 4)
  filter.insert("duplicate")
  filter.insert("duplicate")
  filter.insert("other")
  let restored = @src.ConcurrentCountingBloomFilter::from_bytes(filter.to_bytes())
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
test "concurrent counting filter serialization round trips empty filters" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(16, 1)
  let restored = @src.ConcurrentCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.slot_count(), 16)
}

///|
test "concurrent blocked bloom filter serialization round trip" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(4096, 5)
  let keys = ["alpha", "beta", "gamma", "delta"]
  filter.insert_all(keys)
  filter.insert(42)
  let restored = @src.ConcurrentBlockedBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.bit_count(), filter.bit_count())
  assert_eq(restored.block_count(), filter.block_count())
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
test "concurrent blocked bloom filter serialization round trips empty filters" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 3)
  let restored = @src.ConcurrentBlockedBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.bit_count(), 1024)
  assert_eq(restored.block_count(), 2)
  assert_eq(restored.count(), 0)
}

///|
test "concurrent cuckoo filter serialization round trip" {
  let filter = @src.ConcurrentCuckooFilter::with_size(64, 4)
  let keys = ["a", "b", "c", "d", "e"]
  assert_true(filter.insert_all(keys))
  let restored = @src.ConcurrentCuckooFilter::from_bytes(filter.to_bytes())
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
test "concurrent cuckoo filter serialization round trips empty filters" {
  let filter = @src.ConcurrentCuckooFilter::with_size(1, 1)
  let restored = @src.ConcurrentCuckooFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.bucket_count(), 1)
}

///|
test "concurrent compact counting filter serialization round trip" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::new(100, 0.01)
  for i = 0; i < 100; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  filter.insert("key-0")
  assert_true(filter.remove("key-1"))
  let restored = @src.ConcurrentCompactCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.slot_count(), filter.slot_count())
  assert_eq(restored.hash_count(), filter.hash_count())
  assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
  assert_eq(restored.memory_bytes(), filter.memory_bytes())
  assert_eq(restored.count_of("key-0"), 2)
  assert_false(restored.contains("key-1"))
  for i = 2; i < 100; i = i + 1 {
    assert_true(restored.contains("key-" + i.to_string()))
  }
  assert_true(restored.remove("key-0"))
  assert_eq(restored.count_of("key-0"), 1)
}

///|
test "concurrent compact counting filter serialization round trips empty filters" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::new(16, 0.001)
  let restored = @src.ConcurrentCompactCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.count(), 0)
  assert_eq(restored.slot_count(), filter.slot_count())
}

///|
test "concurrent scalable bloom filter serialization round trip" {
  let filter = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  let restored = @src.ConcurrentScalableBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.slice_count(), filter.slice_count())
  assert_eq(restored.capacity(), filter.capacity())
  assert_eq(restored.bit_count(), filter.bit_count())
  assert_eq(restored.set_bit_count(), filter.set_bit_count())
  assert_eq(
    restored.target_false_positive_rate(),
    filter.target_false_positive_rate(),
  )
  for i = 0; i < 40; i = i + 1 {
    assert_true(restored.contains("key-" + i.to_string()))
  }
  assert_true(restored.insert_if_absent("after-restore"))
  assert_eq(restored.count(), filter.count() + 1)
}

///|
test "concurrent scalable bloom filter serialization round trips empty filters" {
  let filter = @src.ConcurrentScalableBloomFilter::new(16, 0.001)
  let restored = @src.ConcurrentScalableBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.slice_count(), 1)
  assert_eq(restored.capacity(), 16L)
  assert_eq(restored.count(), 0)
  assert_eq(restored.bit_count(), filter.bit_count())
}

///|
test "concurrent scalable counting filter serialization round trip" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(4, 0.01)
  filter.insert("key-0")
  filter.insert("key-0")
  for i = 1; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.remove("key-1"))
  let restored = @src.ConcurrentScalableCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.tracked_key_count(), filter.tracked_key_count())
  assert_eq(restored.slice_count(), filter.slice_count())
  assert_eq(restored.capacity(), filter.capacity())
  assert_eq(restored.slot_count(), filter.slot_count())
  assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
  assert_eq(
    restored.target_false_positive_rate(),
    filter.target_false_positive_rate(),
  )
  assert_eq(restored.count_of("key-0"), 2)
  assert_eq(restored.count_of("key-1"), 0)
  for i = 2; i < 40; i = i + 1 {
    assert_true(restored.contains("key-" + i.to_string()))
  }
  assert_true(restored.remove("key-0"))
  assert_eq(restored.count_of("key-0"), 1)
  assert_true(restored.insert_if_absent("after-restore"))
  assert_eq(restored.count(), filter.count())
}

///|
test "concurrent scalable counting filter serialization round trips empty filters" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(16, 0.001)
  let restored = @src.ConcurrentScalableCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_true(restored.is_empty())
  assert_eq(restored.count(), 0)
  assert_eq(restored.tracked_key_count(), 0)
  assert_eq(restored.slice_count(), 1)
  assert_eq(restored.capacity(), 16L)
  assert_eq(restored.slot_count(), filter.slot_count())
}

///|
test "concurrent serialization rejects wrong filter types" {
  let bloom = @src.BloomFilter::with_size(64, 1)
  @src.ConcurrentBloomFilter::from_bytes(bloom.to_bytes()) |> ignore
  let counting = @src.CountingBloomFilter::with_size(16, 1)
  @src.ConcurrentCountingBloomFilter::from_bytes(counting.to_bytes()) |> ignore
  let blocked = @src.BlockedBloomFilter::with_size(512, 1)
  @src.ConcurrentBlockedBloomFilter::from_bytes(blocked.to_bytes()) |> ignore
  let cuckoo = @src.CuckooFilter::with_size(4, 1)
  @src.ConcurrentCuckooFilter::from_bytes(cuckoo.to_bytes()) |> ignore
  let compact = @src.CompactCountingBloomFilter::with_size(16, 1)
  @src.ConcurrentCompactCountingBloomFilter::from_bytes(compact.to_bytes()) |> ignore
  let scalable = @src.ScalableBloomFilter::new(4, 0.01)
  @src.ConcurrentScalableBloomFilter::from_bytes(scalable.to_bytes()) |> ignore
  let scalable_counting = @src.ScalableCountingBloomFilter::new(4, 0.01)
  @src.ConcurrentScalableCountingBloomFilter::from_bytes(scalable_counting.to_bytes()) |> ignore
}

///|
test "concurrent serialization round trip preserves independent state" {
  let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
  filter.insert("before")
  let snapshot = filter.snapshot()
  filter.insert("after")
  let restored = @src.ConcurrentBloomFilter::from_bytes(filter.to_bytes())
  // The restored filter should have both keys
  assert_true(restored.contains("before"))
  assert_true(restored.contains("after"))
  assert_eq(restored.count(), 2)
  // The original filter is unchanged
  assert_true(filter.contains("before"))
  assert_true(filter.contains("after"))
  assert_eq(filter.count(), 2)
  // The snapshot only has "before"
  assert_true(snapshot.contains("before"))
  assert_false(snapshot.contains("after"))
  assert_eq(snapshot.count(), 1)
}