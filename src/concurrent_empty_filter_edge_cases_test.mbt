///|
/// Edge case tests for concurrent wrapper empty filter operations.
/// Ensures concurrent wrappers handle empty filters correctly like their
/// non-concurrent counterparts.
test "concurrent bloom filter empty filter operations" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  // Empty filter queries
  assert_false(filter.contains("absent"))
  assert_false(filter.contains_all(["a", "b"]))
  assert_false(filter.contains_any(["a", "b"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.set_bit_count(), 0)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_eq(filter.estimated_item_count(), 0.0)

  // Empty filter batch operations
  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)

  // Clear on empty filter
  filter.clear()
  assert_true(filter.is_empty())

  // Set operations with empty filter
  let other = @src.BloomFilter::with_size(1024, 4)
  other.insert("other")
  let combined = filter.union(other)
  assert_true(combined.contains("other"))
  let common = filter.intersection(other)
  assert_true(common.is_empty())
  assert_true(filter.is_disjoint_from(other))
  assert_true(filter.is_subset_of(combined))

  // Merge empty into non-empty
  let target = @src.ConcurrentBloomFilter::with_size(1024, 4)
  target.insert("target")
  let before = target.to_bytes()
  target.merge(@src.BloomFilter::with_size(1024, 4))
  assert_eq(target.to_bytes(), before)
  assert_true(target.contains("target"))
}

///|
test "concurrent blocked bloom filter empty filter operations" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  assert_false(filter.contains("absent"))
  assert_false(filter.contains_all(["a", "b"]))
  assert_false(filter.contains_any(["a", "b"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.set_bit_count(), 0)
  assert_eq(filter.false_positive_rate(), 0.0)

  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)

  filter.clear()
  assert_true(filter.is_empty())

  let other = @src.BlockedBloomFilter::with_size(1024, 4)
  other.insert("other")
  let combined = filter.union(other)
  assert_true(combined.contains("other"))
  let common = filter.intersection(other)
  assert_true(common.is_empty())
  assert_true(filter.is_disjoint_from(other))
  assert_true(filter.is_subset_of(combined))

  let target = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  target.insert("target")
  let before = target.to_bytes()
  target.merge(@src.BlockedBloomFilter::with_size(1024, 4))
  assert_eq(target.to_bytes(), before)
  assert_true(target.contains("target"))
}

///|
test "concurrent counting bloom filter empty filter operations" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  assert_false(filter.contains("absent"))
  assert_eq(filter.count_of("absent"), 0)
  assert_false(filter.remove("absent"))
  assert_false(filter.contains_all(["a", "b"]))
  assert_false(filter.contains_any(["a", "b"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.false_positive_rate(), 0.0)

  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))

  filter.clear()
  assert_true(filter.is_empty())

  let other = @src.CountingBloomFilter::with_size(256, 4)
  other.insert("other")
  let combined = filter.union(other)
  assert_true(combined.contains("other"))
  let common = filter.intersection(other)
  assert_true(common.is_empty())
  assert_true(filter.is_disjoint_from(other))
  assert_true(filter.is_subset_of(combined))

  let target = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  target.insert("target")
  let before = target.to_bytes()
  target.merge(@src.CountingBloomFilter::with_size(256, 4))
  assert_eq(target.to_bytes(), before)
  assert_true(target.contains("target"))
}

///|
test "concurrent compact counting bloom filter empty filter operations" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  assert_false(filter.contains("absent"))
  assert_eq(filter.count_of("absent"), 0)
  assert_false(filter.remove("absent"))
  assert_false(filter.contains_all(["a", "b"]))
  assert_false(filter.contains_any(["a", "b"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.false_positive_rate(), 0.0)

  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))

  filter.clear()
  assert_true(filter.is_empty())

  let other = @src.CompactCountingBloomFilter::with_size(256, 4)
  other.insert("other")
  let combined = filter.union(other)
  assert_true(combined.contains("other"))
  let common = filter.intersection(other)
  assert_true(common.is_empty())
  assert_true(filter.is_disjoint_from(other))
  assert_true(filter.is_subset_of(combined))

  let target = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  target.insert("target")
  let before = target.to_bytes()
  target.merge(@src.CompactCountingBloomFilter::with_size(256, 4))
  assert_eq(target.to_bytes(), before)
  assert_true(target.contains("target"))
}

///|
test "concurrent cuckoo filter empty filter operations" {
  let filter = @src.ConcurrentCuckooFilter::with_size(16, 4)
  assert_false(filter.contains("absent"))
  assert_eq(filter.count_of("absent"), 0)
  assert_false(filter.remove("absent"))
  assert_false(filter.contains_all(["a", "b"]))
  assert_false(filter.contains_any(["a", "b"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.remaining_capacity(), 64)
  assert_false(filter.is_full())
  assert_eq(filter.load_factor(), 0.0)

  let empty : Array[String] = []
  ignore(filter.insert_all(empty))
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))

  filter.clear()
  assert_true(filter.is_empty())

  let other = @src.CuckooFilter::with_size(16, 4)
  ignore(other.insert("other"))
  let combined_opt = filter.union(other)
  match combined_opt {
    Some(combined) => {
      assert_true(combined.contains("other"))
      let common = filter.intersection(other)
      assert_true(common.is_empty())
      assert_true(filter.is_disjoint_from(other))
      assert_true(filter.is_subset_of(combined))
    }
    None => abort("union of empty filters should succeed")
  }

  let target = @src.ConcurrentCuckooFilter::with_size(16, 4)
  ignore(target.insert("target"))
  let before = target.to_bytes()
  assert_true(target.merge(@src.CuckooFilter::with_size(16, 4)))
  assert_eq(target.to_bytes(), before)
  assert_true(target.contains("target"))
}

///|
test "concurrent scalable bloom filter empty filter operations" {
  let filter = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  assert_false(filter.contains("absent"))
  assert_false(filter.contains_all(["a", "b"]))
  assert_false(filter.contains_any(["a", "b"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.set_bit_count(), 0)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_eq(filter.target_false_positive_rate(), 0.01)

  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)

  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.slice_count(), 1)

  let other = @src.ScalableBloomFilter::new(4, 0.01)
  ignore(other.insert("other"))
  let combined = filter.union(other)
  assert_true(combined.contains("other"))
  let common = filter.intersection(other)
  assert_true(common.is_empty())
  assert_true(filter.is_disjoint_from(other))
  assert_true(filter.is_subset_of(combined))

  let target = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  ignore(target.insert("target"))
  let before = target.to_bytes()
  target.merge(@src.ScalableBloomFilter::new(4, 0.01))
  assert_eq(target.to_bytes(), before)
  assert_true(target.contains("target"))
}

///|
test "concurrent scalable counting bloom filter empty filter operations" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(4, 0.01)
  assert_false(filter.contains("absent"))
  assert_eq(filter.count_of("absent"), 0)
  assert_false(filter.remove("absent"))
  assert_false(filter.contains_all(["a", "b"]))
  assert_false(filter.contains_any(["a", "b"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.tracked_key_count(), 0)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_eq(filter.target_false_positive_rate(), 0.01)

  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))

  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.tracked_key_count(), 0)

  let other = @src.ScalableCountingBloomFilter::new(4, 0.01)
  ignore(other.insert("other"))
  let combined = filter.union(other)
  assert_true(combined.contains("other"))
  let common = filter.intersection(other)
  assert_true(common.is_empty())
  assert_true(filter.is_disjoint_from(other))
  assert_true(filter.is_subset_of(combined))

  let target = @src.ConcurrentScalableCountingBloomFilter::new(4, 0.01)
  ignore(target.insert("target"))
  let before = target.to_bytes()
  target.merge(@src.ScalableCountingBloomFilter::new(4, 0.01))
  assert_eq(target.to_bytes(), before)
  assert_true(target.contains("target"))
}

///|
test "concurrent wrapper empty filter serialization round trip" {
  // Test all concurrent wrapper types with empty filters
  let bloom = @src.ConcurrentBloomFilter::with_size(1024, 4)
  let restored_bloom = @src.ConcurrentBloomFilter::from_bytes(bloom.to_bytes())
  assert_true(restored_bloom.is_empty())
  assert_eq(restored_bloom.count(), 0)

  let blocked = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  let restored_blocked = @src.ConcurrentBlockedBloomFilter::from_bytes(blocked.to_bytes())
  assert_true(restored_blocked.is_empty())
  assert_eq(restored_blocked.count(), 0)

  let counting = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  let restored_counting = @src.ConcurrentCountingBloomFilter::from_bytes(counting.to_bytes())
  assert_true(restored_counting.is_empty())
  assert_eq(restored_counting.count(), 0)

  let compact = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  let restored_compact = @src.ConcurrentCompactCountingBloomFilter::from_bytes(compact.to_bytes())
  assert_true(restored_compact.is_empty())
  assert_eq(restored_compact.count(), 0)

  let cuckoo = @src.ConcurrentCuckooFilter::with_size(16, 4)
  let restored_cuckoo = @src.ConcurrentCuckooFilter::from_bytes(cuckoo.to_bytes())
  assert_true(restored_cuckoo.is_empty())
  assert_eq(restored_cuckoo.count(), 0)

  let scalable = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  let restored_scalable = @src.ConcurrentScalableBloomFilter::from_bytes(scalable.to_bytes())
  assert_true(restored_scalable.is_empty())
  assert_eq(restored_scalable.count(), 0)
  assert_eq(restored_scalable.slice_count(), 1)

  let scalable_counting = @src.ConcurrentScalableCountingBloomFilter::new(4, 0.01)
  let restored_sc = @src.ConcurrentScalableCountingBloomFilter::from_bytes(scalable_counting.to_bytes())
  assert_true(restored_sc.is_empty())
  assert_eq(restored_sc.count(), 0)
  assert_eq(restored_sc.slice_count(), 1)
  assert_eq(restored_sc.tracked_key_count(), 0)
}

///|
test "concurrent wrapper empty filter merge from non-empty source" {
  // Test merging non-empty into empty receiver for all types
  let source_bloom = @src.BloomFilter::with_size(1024, 4)
  source_bloom.insert("source")
  let target_bloom = @src.ConcurrentBloomFilter::with_size(1024, 4)
  target_bloom.merge(source_bloom)
  assert_true(target_bloom.contains("source"))
  assert_eq(target_bloom.count(), 1)

  let source_blocked = @src.BlockedBloomFilter::with_size(1024, 4)
  source_blocked.insert("source")
  let target_blocked = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  target_blocked.merge(source_blocked)
  assert_true(target_blocked.contains("source"))

  let source_counting = @src.CountingBloomFilter::with_size(256, 4)
  source_counting.insert("source")
  let target_counting = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  target_counting.merge(source_counting)
  assert_true(target_counting.contains("source"))

  let source_compact = @src.CompactCountingBloomFilter::with_size(256, 4)
  source_compact.insert("source")
  let target_compact = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  target_compact.merge(source_compact)
  assert_true(target_compact.contains("source"))

  let source_cuckoo = @src.CuckooFilter::with_size(16, 4)
  ignore(source_cuckoo.insert("source"))
  let target_cuckoo = @src.ConcurrentCuckooFilter::with_size(16, 4)
  assert_true(target_cuckoo.merge(source_cuckoo))
  assert_true(target_cuckoo.contains("source"))

  let source_scalable = @src.ScalableBloomFilter::new(4, 0.01)
  ignore(source_scalable.insert("source"))
  let target_scalable = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  target_scalable.merge(source_scalable)
  assert_true(target_scalable.contains("source"))

  let source_sc = @src.ScalableCountingBloomFilter::new(4, 0.01)
  ignore(source_sc.insert("source"))
  let target_sc = @src.ConcurrentScalableCountingBloomFilter::new(4, 0.01)
  target_sc.merge(source_sc)
  assert_true(target_sc.contains("source"))
}

///|
test "concurrent wrapper full filter operations" {
  // Test full filter behavior on concurrent wrappers
  let bloom = @src.ConcurrentBloomFilter::with_size(64, 100) // Very wide hash count
  // Fill the filter
  for i = 0; i < 1000; i = i + 1 {
    bloom.insert("key-" + i.to_string())
  }
  assert_true(bloom.is_full())
  assert_false(bloom.insert_if_absent("new-key"))
  assert_eq(bloom.count(), 1000)

  let blocked = @src.ConcurrentBlockedBloomFilter::with_size(512, 100)
  for i = 0; i < 1000; i = i + 1 {
    blocked.insert("key-" + i.to_string())
  }
  assert_true(blocked.is_full())
  assert_false(blocked.insert_if_absent("new-key"))

  let counting = @src.ConcurrentCountingBloomFilter::with_size(16, 100)
  for i = 0; i < 100; i = i + 1 {
    counting.insert("key-" + i.to_string())
  }
  // Counting filters can be full but still accept inserts (counters saturate)
  assert_true(counting.is_full())
  // insert_if_absent should return false on full filter
  assert_false(counting.insert_if_absent("new-key"))

  let compact = @src.ConcurrentCompactCountingBloomFilter::with_size(16, 100)
  for i = 0; i < 100; i = i + 1 {
    compact.insert("key-" + i.to_string())
  }
  assert_true(compact.is_full())
  assert_false(compact.insert_if_absent("new-key"))

  let cuckoo = @src.ConcurrentCuckooFilter::with_size(1, 1)
  ignore(cuckoo.insert("only"))
  assert_true(cuckoo.is_full())
  assert_false(cuckoo.insert("another"))
  assert_false(cuckoo.insert_if_absent("another"))

  // Scalable filters grow instead of becoming full
  let scalable = @src.ConcurrentScalableBloomFilter::new(1, 0.5) // High rate, small capacity
  for i = 0; i < 10; i = i + 1 {
    scalable.insert("key-" + i.to_string())
  }
  // Scalable filters don't have is_full, they grow instead

  let sc = @src.ConcurrentScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 10; i = i + 1 {
    sc.insert("key-" + i.to_string())
  }
  // Scalable counting filters don't have is_full, they grow instead
}

///|
test "concurrent wrapper snapshot on empty filter" {
  let bloom = @src.ConcurrentBloomFilter::with_size(1024, 4)
  let snapshot = bloom.snapshot()
  assert_true(snapshot.is_empty())
  assert_eq(snapshot.count(), 0)

  let blocked = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  let snap2 = blocked.snapshot()
  assert_true(snap2.is_empty())

  let counting = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  let snap3 = counting.snapshot()
  assert_true(snap3.is_empty())

  let compact = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  let snap4 = compact.snapshot()
  assert_true(snap4.is_empty())

  let cuckoo = @src.ConcurrentCuckooFilter::with_size(16, 4)
  let snap5 = cuckoo.snapshot()
  assert_true(snap5.is_empty())

  let scalable = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  let snap6 = scalable.snapshot()
  assert_true(snap6.is_empty())
  assert_eq(snap6.slice_count(), 1)

  let sc = @src.ConcurrentScalableCountingBloomFilter::new(4, 0.01)
  let snap7 = sc.snapshot()
  assert_true(snap7.is_empty())
  assert_eq(snap7.slice_count(), 1)
  assert_eq(snap7.tracked_key_count(), 0)
}