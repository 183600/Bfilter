///|
test "clearing empty fixed-size filters keeps their serialized state" {
  let bloom = @src.BloomFilter::with_size(1024, 4)
  let bloom_before = bloom.to_bytes()
  bloom.clear()
  assert_eq(bloom.to_bytes(), bloom_before)

  let blocked = @src.BlockedBloomFilter::with_size(1024, 4)
  let blocked_before = blocked.to_bytes()
  blocked.clear()
  assert_eq(blocked.to_bytes(), blocked_before)

  let counting = @src.CountingBloomFilter::with_size(1024, 4)
  let counting_before = counting.to_bytes()
  counting.clear()
  assert_eq(counting.to_bytes(), counting_before)

  let compact = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let compact_before = compact.to_bytes()
  compact.clear()
  assert_eq(compact.to_bytes(), compact_before)

  let cuckoo = @src.CuckooFilter::with_size(16, 4)
  let cuckoo_before = cuckoo.to_bytes()
  cuckoo.clear()
  assert_eq(cuckoo.to_bytes(), cuckoo_before)
}

///|
test "clearing a drained counting filter resets it without residue" {
  let fresh = @src.CountingBloomFilter::with_size(1024, 4)
  let drained = @src.CountingBloomFilter::with_size(1024, 4)
  drained.insert("temporary")
  assert_true(drained.remove("temporary"))
  drained.clear()
  assert_true(drained.is_empty())
  assert_eq(drained.to_bytes(), fresh.to_bytes())

  let compact_fresh = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let compact_drained = @src.CompactCountingBloomFilter::with_size(1024, 4)
  compact_drained.insert("temporary")
  assert_true(compact_drained.remove("temporary"))
  compact_drained.clear()
  assert_true(compact_drained.is_empty())
  assert_eq(compact_drained.to_bytes(), compact_fresh.to_bytes())
}

///|
test "clearing a drained cuckoo filter restores the fresh eviction state" {
  let fresh = @src.CuckooFilter::with_size(16, 4)
  let drained = @src.CuckooFilter::with_size(16, 4)
  assert_true(drained.insert("temporary"))
  assert_true(drained.remove("temporary"))
  assert_true(drained.is_empty())
  drained.clear()
  assert_eq(drained.to_bytes(), fresh.to_bytes())
}

///|
test "scalable bloom clear reuses the first slice and drops later slices" {
  let filter = @src.ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  filter.clear()
  let fresh = @src.ScalableBloomFilter::new(2, 0.01)
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 0)
  assert_eq(filter.capacity(), 2L)
  assert_eq(filter.to_bytes(), fresh.to_bytes())
  assert_true(filter.insert_if_absent("after-clear"))
  assert_true(filter.contains("after-clear"))
}

///|
test "scalable counting clear reuses the first slice and drops later slices" {
  let filter = @src.ScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  filter.clear()
  let fresh = @src.ScalableCountingBloomFilter::new(2, 0.01)
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.count(), 0)
  assert_eq(filter.tracked_key_count(), 0)
  assert_eq(filter.capacity(), 2L)
  assert_eq(filter.to_bytes(), fresh.to_bytes())
  assert_true(filter.insert_if_absent("after-clear"))
  assert_eq(filter.count_of("after-clear"), 1)
  assert_true(filter.remove("after-clear"))
}
