///|
test "bloom family self union doubles the conservative insertion count" {
  let bloom = @src.BloomFilter::with_size(4096, 4)
  bloom.insert_all(["a", "b", "c"])
  let bloom_union = bloom.union(bloom)
  assert_eq(bloom_union.count(), bloom.count() * 2)
  assert_eq(bloom_union.bit_count(), bloom.bit_count())
  assert_eq(bloom_union.set_bit_count(), bloom.set_bit_count())
  assert_true(bloom_union.contains_all(["a", "b", "c"]))
  let bloom_merge = bloom.copy()
  bloom_merge.merge(bloom)
  assert_eq(bloom_merge.to_bytes(), bloom_union.to_bytes())

  let blocked = @src.BlockedBloomFilter::with_size(4096, 4)
  blocked.insert_all(["a", "b", "c"])
  let blocked_union = blocked.union(blocked)
  assert_eq(blocked_union.count(), blocked.count() * 2)
  assert_eq(blocked_union.set_bit_count(), blocked.set_bit_count())
  assert_true(blocked_union.contains_all(["a", "b", "c"]))
  let blocked_merge = blocked.copy()
  blocked_merge.merge(blocked)
  assert_eq(blocked_merge.to_bytes(), blocked_union.to_bytes())
}

///|
test "counting family self union keeps counters and adds counts" {
  let counting = @src.CountingBloomFilter::with_size(4096, 4)
  counting.insert("a")
  counting.insert("a")
  counting.insert("b")
  let counting_union = counting.union(counting)
  assert_eq(counting_union.count(), counting.count() * 2)
  assert_eq(counting_union.count_of("a"), counting.count_of("a"))
  assert_eq(counting_union.count_of("b"), counting.count_of("b"))
  assert_true(counting_union.contains_all(["a", "b"]))
  let counting_merge = counting.copy()
  counting_merge.merge(counting)
  assert_eq(counting_merge.to_bytes(), counting_union.to_bytes())

  let compact = @src.CompactCountingBloomFilter::with_size(4096, 4)
  compact.insert("a")
  compact.insert("a")
  compact.insert("b")
  let compact_union = compact.union(compact)
  assert_eq(compact_union.count(), compact.count() * 2)
  assert_eq(compact_union.count_of("a"), compact.count_of("a"))
  assert_eq(compact_union.count_of("b"), compact.count_of("b"))
  assert_true(compact_union.contains_all(["a", "b"]))
  let compact_merge = compact.copy()
  compact_merge.merge(compact)
  assert_eq(compact_merge.to_bytes(), compact_union.to_bytes())
}

///|
test "scalable bloom self union preserves bits and doubles counts" {
  let filter = @src.ScalableBloomFilter::new(2, 0.01)
  filter.insert_all(["a", "b", "c", "d", "e"])
  let before = filter.count()
  let union = filter.union(filter)
  assert_eq(union.count(), before * 2)
  assert_eq(union.slice_count(), filter.slice_count())
  assert_eq(union.bit_count(), filter.bit_count())
  assert_true(union.contains_all(["a", "b", "c", "d", "e"]))
  let merged = filter.copy()
  merged.merge(filter)
  assert_eq(merged.to_bytes(), union.to_bytes())
  let restored = @src.ScalableBloomFilter::from_bytes(union.to_bytes())
  assert_eq(restored.count(), union.count())
  assert_true(restored.contains_all(["a", "b", "c", "d", "e"]))
}

///|
test "scalable counting self union preserves tracked multiplicities" {
  let filter = @src.ScalableCountingBloomFilter::new(2, 0.01)
  filter.insert("a")
  filter.insert("a")
  filter.insert_all(["b", "c", "d", "e"])
  let before = filter.count()
  let union = filter.union(filter)
  assert_eq(union.count(), before)
  assert_eq(union.count_of("a"), filter.count_of("a"))
  assert_eq(union.tracked_key_count(), filter.tracked_key_count())
  assert_true(union.contains_all(["a", "b", "c", "d", "e"]))
  assert_true(union.remove("a"))
  assert_eq(union.count_of("a"), 1)
  let merged = filter.copy()
  merged.merge(filter)
  assert_eq(merged.count(), before)
  assert_eq(merged.count_of("a"), filter.count_of("a"))
}

///|
test "cuckoo self union stores both copies when capacity allows" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_true(filter.insert_all(["a", "b"]))
  let before = filter.count()
  match filter.union(filter) {
    Some(union) => {
      assert_eq(union.count(), before * 2)
      assert_true(union.contains_all(["a", "b"]))
      assert_true(filter.is_subset_of(union))
    }
    None => abort("self union unexpectedly ran out of room")
  }
  let merged = filter.copy()
  assert_true(merged.merge(filter))
  assert_eq(merged.count(), before * 2)
  assert_true(merged.contains_all(["a", "b"]))
  let restored = @src.CuckooFilter::from_bytes(merged.to_bytes())
  assert_eq(restored.count(), merged.count())
  assert_true(restored.contains_all(["a", "b"]))
}
