///|
test "concurrent blocked bloom filter exposes documented set operations" {
  let left = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  let right = @src.BlockedBloomFilter::with_size(1024, 4)
  left.insert("shared")
  left.insert("left-only")
  right.insert("shared")
  right.insert("right-only")
  let combined = left.union(right)
  assert_true(combined.contains_all(["shared", "left-only", "right-only"]))
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  let common = left.intersection(right)
  assert_true(common.contains("shared"))
  assert_true(common.is_subset_of(left.snapshot()))
  assert_true(common.is_subset_of(right))
  assert_true(left.is_disjoint_from(@src.BlockedBloomFilter::with_size(1024, 4)))
  left.merge(right)
  assert_true(left.contains("right-only"))
  let restored = @src.ConcurrentBlockedBloomFilter::from_bytes(left.to_bytes())
  assert_true(restored.contains_all(["shared", "left-only", "right-only"]))
  left.clear()
  assert_true(left.is_empty())
}

///|
test "concurrent compact counting filter exposes documented set operations" {
  let left = @src.ConcurrentCompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
  left.insert("shared")
  left.insert("shared")
  left.insert("left-only")
  right.insert("shared")
  right.insert("right-only")
  assert_eq(left.count_of("shared"), 2)
  let combined = left.union(right)
  assert_true(combined.contains_all(["shared", "left-only", "right-only"]))
  assert_eq(combined.count_of("shared"), 2)
  assert_true(left.is_subset_of(combined))
  let common = left.intersection(right)
  assert_eq(common.count_of("shared"), 1)
  assert_true(common.is_subset_of(left.snapshot()))
  assert_true(common.is_subset_of(right))
  left.merge(right)
  assert_true(left.contains("right-only"))
  assert_true(left.remove_all(["shared", "left-only", "right-only"]))
  assert_eq(left.count_of("shared"), 1)
  assert_true(left.remove("shared"))
  assert_eq(left.occupied_slot_count(), 0)
  assert_eq(left.count_of("shared"), 0)
  // Merge keeps the summed insertion count as a conservative upper bound, so
  // removing every recorded key can leave count() above zero while no counter
  // remains occupied.
  let restored = @src.ConcurrentCompactCountingBloomFilter::from_bytes(
    left.to_bytes(),
  )
  assert_eq(restored.occupied_slot_count(), 0)
  assert_eq(restored.count(), left.count())
}

///|
test "concurrent scalable bloom filter exposes documented set operations" {
  let left = @src.ConcurrentScalableBloomFilter::new(2, 0.01)
  let right = @src.ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    left.insert("left-" + i.to_string())
    right.insert("right-" + i.to_string())
  }
  let combined = left.union(right)
  assert_true(combined.contains("left-0"))
  assert_true(combined.contains("right-0"))
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  let common = left.intersection(right)
  assert_eq(common.count(), left.count().min(right.count()))
  left.merge(right)
  assert_true(left.contains("right-19"))
  assert_true(left.is_disjoint_from(@src.ScalableBloomFilter::new(2, 0.01)))
  left.clear()
  assert_eq(left.slice_count(), 1)
  assert_true(left.is_empty())
  assert_true(left.target_false_positive_rate() == 0.01)
}

///|
test "concurrent scalable counting filter exposes documented set operations" {
  let left = @src.ConcurrentScalableCountingBloomFilter::new(2, 0.01)
  let right = @src.ScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    left.insert("left-" + i.to_string())
    right.insert("right-" + i.to_string())
  }
  left.insert("shared")
  right.insert("shared")
  let combined = left.union(right)
  assert_eq(combined.count_of("shared"), 1)
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  let common = left.intersection(right)
  assert_eq(common.count_of("shared"), 1)
  assert_true(common.is_subset_of(left.snapshot()))
  left.merge(right)
  assert_true(left.contains("right-19"))
  assert_eq(left.count_of("shared"), 1)
  assert_true(left.remove_all(["shared", "right-0"]))
  assert_eq(left.count_of("shared"), 0)
  assert_true(
    left.is_disjoint_from(@src.ScalableCountingBloomFilter::new(2, 0.01)),
  )
  let restored = @src.ConcurrentScalableCountingBloomFilter::from_bytes(
    left.to_bytes(),
  )
  assert_eq(restored.count(), left.count())
  assert_eq(restored.tracked_key_count(), left.tracked_key_count())
}

///|
test "grown empty scalable counting merge into a shorter receiver serializes" {
  let receiver = @src.ScalableCountingBloomFilter::new(1, 0.01)
  receiver.insert("keep")
  let grown = @src.ScalableCountingBloomFilter::new(1, 0.01)
  for i = 0; i < 3; i = i + 1 {
    grown.insert("grow-" + i.to_string())
  }
  for i = 0; i < 3; i = i + 1 {
    assert_true(grown.remove("grow-" + i.to_string()))
  }
  assert_true(grown.is_empty())
  assert_true(grown.slice_count() > receiver.slice_count())
  receiver.merge(grown)
  assert_eq(receiver.slice_count(), grown.slice_count())
  assert_eq(receiver.count(), 1)
  assert_true(receiver.contains("keep"))
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    receiver.to_bytes(),
  )
  assert_eq(restored.slice_count(), receiver.slice_count())
  assert_eq(restored.count(), 1)
  assert_true(restored.contains("keep"))
  assert_true(restored.remove("keep"))
  assert_true(restored.is_empty())
}
