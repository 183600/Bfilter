///|
test "bloom filter contains_any returns true when any key is present" {
  let filter = @src.BloomFilter::with_size(4096, 4)
  filter.insert("alpha")
  assert_true(filter.contains_any(["alpha", "beta"]))
  assert_true(filter.contains_any(["alpha"]))
  assert_false(filter.contains_any(["gamma", "beta"]))
}

///|
test "bloom filter insert_all_if_absent adds only new keys" {
  let filter = @src.BloomFilter::with_size(4096, 4)
  filter.insert("alpha")
  let count = filter.insert_all_if_absent(["alpha", "beta", "gamma"])
  assert_eq(count, 2)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains("beta"))
  assert_true(filter.contains("gamma"))
}

///|
test "count bloom filter insert_all_if_absent adds only new keys" {
  let filter = @src.CountingBloomFilter::with_size(4096, 4)
  filter.insert("alpha")
  let count = filter.insert_all_if_absent(["alpha", "beta", "gamma"])
  assert_eq(count, 2)
  assert_eq(filter.count_of("alpha"), 1)
  assert_eq(filter.count_of("beta"), 1)
  assert_eq(filter.count_of("gamma"), 1)
}

///|
test "cuckoo filter insert_all_if_absent adds only new keys" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  ignore(filter.insert("alpha"))
  let count = filter.insert_all_if_absent(["alpha", "beta", "gamma"])
  assert_eq(count, 2)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains("beta"))
  assert_true(filter.contains("gamma"))
}

///|
test "cuckoo filter remove_all reports failure but keeps removing later keys" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  let keys = ["a", "b", "c"]
  assert_true(filter.insert_all(keys))
  let batch = ["a", "missing", "b"]
  assert_false(filter.remove_all(batch))
  assert_false(filter.contains("a"))
  assert_false(filter.contains("b"))
  assert_true(filter.contains("c"))
  assert_eq(filter.count(), 1)
}

///|
test "scalable bloom filter contains_any works across slices" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  filter.insert("alpha")
  filter.insert("beta")
  assert_true(filter.contains_any(["alpha", "beta"]))
  filter.insert("gamma")
  assert_true(filter.contains_any(["gamma", "delta"]))
  assert_false(filter.contains_any(["delta", "epsilon"]))
}

///|
test "scalable counting bloom filter contains_any works across slices" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("alpha")
  filter.insert("beta")
  assert_true(filter.contains_any(["alpha", "beta"]))
  assert_false(filter.contains_any(["gamma", "delta"]))
}

///|
test "blocked bloom filter insert_all_if_absent works correctly" {
  let filter = @src.BlockedBloomFilter::with_size(4096, 4)
  filter.insert("alpha")
  let count = filter.insert_all_if_absent(["alpha", "beta", "gamma"])
  assert_eq(count, 2)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains("beta"))
  assert_true(filter.contains("gamma"))
}

///|
test "compact counting bloom filter remove_all with empty keys returns true" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  let empty : Array[String] = []
  let result = filter.remove_all(empty)
  assert_true(result)
  assert_true(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_eq(filter.count(), 2)
}

///|
test "counting bloom filter remove_all with empty keys returns true" {
  let filter = @src.CountingBloomFilter::with_size(256, 4)
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  let empty : Array[String] = []
  let result = filter.remove_all(empty)
  assert_true(result)
  assert_eq(filter.count_of("a"), 1)
  assert_eq(filter.count_of("b"), 1)
  assert_eq(filter.count(), 2)
}

///|
test "cuckoo filter remove_all with empty keys returns true" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  let empty : Array[String] = []
  let result = filter.remove_all(empty)
  assert_true(result)
  assert_true(filter.contains("a"))
  assert_true(filter.contains("b"))
}

///|
test "bloom filter merge preserves insertion count" {
  let left = @src.BloomFilter::with_size(1024, 4)
  left.insert("a")
  left.insert("b")
  let right = @src.BloomFilter::with_size(1024, 4)
  right.insert("c")
  right.insert("d")
  left.merge(right)
  assert_eq(left.count(), 4)
  assert_true(left.contains("a"))
  assert_true(left.contains("b"))
  assert_true(left.contains("c"))
  assert_true(left.contains("d"))
}

///|
test "bloom filter intersection returns intersection keys" {
  let left = @src.BloomFilter::with_size(1024, 4)
  left.insert("a")
  left.insert("b")
  left.insert("c")
  let right = @src.BloomFilter::with_size(1024, 4)
  right.insert("b")
  right.insert("c")
  right.insert("d")
  let intersection = left.intersection(right)
  assert_false(intersection.contains("a"))
  assert_true(intersection.contains("b"))
  assert_true(intersection.contains("c"))
  assert_false(intersection.contains("d"))
}

///|
test "bloom filter union returns correct membership" {
  let left = @src.BloomFilter::with_size(1024, 4)
  left.insert("a")
  left.insert("b")
  let right = @src.BloomFilter::with_size(1024, 4)
  right.insert("b")
  right.insert("c")
  let union = left.union(right)
  assert_true(union.contains("a"))
  assert_true(union.contains("b"))
  assert_true(union.contains("c"))
}

///|
test "blocked bloom filter union works with same layout" {
  let left = @src.BlockedBloomFilter::with_size(1024, 4)
  left.insert("a")
  left.insert("b")
  let right = @src.BlockedBloomFilter::with_size(1024, 4)
  right.insert("b")
  right.insert("c")
  let union = left.union(right)
  assert_true(union.contains("a"))
  assert_true(union.contains("b"))
  assert_true(union.contains("c"))
}

///|
test "cuckoo filter union succeeds with compatible layouts" {
  let left = @src.CuckooFilter::with_size(16, 4)
  ignore(left.insert("a"))
  ignore(left.insert("b"))
  let right = @src.CuckooFilter::with_size(16, 4)
  ignore(right.insert("b"))
  ignore(right.insert("c"))
  match left.union(right) {
    Some(union) => {
      assert_true(union.contains("a"))
      assert_true(union.contains("b"))
      assert_true(union.contains("c"))
    }
    None => abort("union should succeed")
  }
}

///|
test "cuckoo filter intersection preserves smaller multiplicity across buckets" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  ignore(filter.insert("duplicate"))
  ignore(filter.insert("duplicate"))
  ignore(filter.insert("duplicate"))
  let mirror = filter.copy()
  assert_eq(mirror.count_of("duplicate"), 3)
  assert_true(filter.is_subset_of(mirror))
  assert_true(mirror.is_subset_of(filter))
  let common = filter.intersection(mirror)
  assert_eq(common.count(), 3)
  assert_true(common.contains("duplicate"))
}

///|
test "scalable bloom filter merge handles different slice counts" {
  let left = @src.ScalableBloomFilter::new(100, 0.01)
  left.insert("a")
  left.insert("b")
  let right = @src.ScalableBloomFilter::new(100, 0.01)
  right.insert("c")
  right.insert("d")
  left.merge(right)
  assert_true(left.contains("a"))
  assert_true(left.contains("b"))
  assert_true(left.contains("c"))
  assert_true(left.contains("d"))
}

///|
test "scalable counting bloom filter merge handles different tracked keys" {
  let left = @src.ScalableCountingBloomFilter::new(100, 0.01)
  left.insert("a")
  left.insert("b")
  let right = @src.ScalableCountingBloomFilter::new(100, 0.01)
  right.insert("c")
  right.insert("d")
  left.merge(right)
  assert_eq(left.count_of("a"), 1)
  assert_eq(left.count_of("b"), 1)
  assert_eq(left.count_of("c"), 1)
  assert_eq(left.count_of("d"), 1)
}

///|
test "bloom filter concurrent merge with external bloom filter uses same layout" {
  let concurrent = @src.ConcurrentBloomFilter::new(100, 0.01)
  concurrent.insert("a")
  let (bits, hashes) = @src.BloomFilter::optimal_size(100, 0.01)
  let external = @src.BloomFilter::with_size(bits, hashes)
  external.insert("b")
  concurrent.merge(external)
  assert_true(concurrent.contains("a"))
  assert_true(concurrent.contains("b"))
}

///|
test "bloom filter concurrent union with external bloom filter uses same layout" {
  let concurrent = @src.ConcurrentBloomFilter::new(100, 0.01)
  concurrent.insert("a")
  let (bits, hashes) = @src.BloomFilter::optimal_size(100, 0.01)
  let external = @src.BloomFilter::with_size(bits, hashes)
  external.insert("b")
  let result = concurrent.union(external)
  assert_true(result.contains("a"))
  assert_true(result.contains("b"))
}

///|
test "bloom filter is_disjoint_from returns true for disjoint filters" {
  let left = @src.BloomFilter::with_size(4096, 4)
  left.insert("a")
  let right = @src.BloomFilter::with_size(4096, 4)
  right.insert("b")
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
}

///|
test "counting bloom filter is_disjoint_from checks occupied slots" {
  let left = @src.CountingBloomFilter::with_size(4096, 4)
  left.insert("a")
  let right = @src.CountingBloomFilter::with_size(4096, 4)
  right.insert("b")
  assert_true(left.is_disjoint_from(right))
}

///|
test "compact counting is_disjoint_from checks occupied slots" {
  let left = @src.CompactCountingBloomFilter::with_size(4096, 4)
  left.insert("a")
  let right = @src.CompactCountingBloomFilter::with_size(4096, 4)
  right.insert("b")
  assert_true(left.is_disjoint_from(right))
}

///|
test "bloom filter is_subset_of for proper subset" {
  let superset = @src.BloomFilter::with_size(4096, 4)
  superset.insert("a")
  superset.insert("b")
  superset.insert("c")
  let subset = @src.BloomFilter::with_size(4096, 4)
  subset.insert("a")
  subset.insert("b")
  assert_true(subset.is_subset_of(superset))
  assert_false(superset.is_subset_of(subset))
}

///|
test "blocked bloom filter is_subset_of for proper subset" {
  let superset = @src.BlockedBloomFilter::with_size(4096, 4)
  superset.insert("a")
  superset.insert("b")
  let subset = @src.BlockedBloomFilter::with_size(4096, 4)
  subset.insert("a")
  assert_true(subset.is_subset_of(superset))
  assert_false(superset.is_subset_of(subset))
}

///|
test "bloom filter with minimum hash count" {
  let filter = @src.BloomFilter::with_size(64, 1)
  filter.insert("test")
  assert_true(filter.contains("test"))
  assert_eq(filter.hash_count(), 1)
}

///|
test "counting bloom filter with minimum hash count" {
  let filter = @src.CountingBloomFilter::with_size(16, 1)
  filter.insert("test")
  assert_true(filter.contains("test"))
  assert_eq(filter.hash_count(), 1)
}

///|
test "blocked bloom filter with minimum hash count" {
  let filter = @src.BlockedBloomFilter::with_size(512, 1)
  filter.insert("test")
  assert_true(filter.contains("test"))
  assert_eq(filter.hash_count(), 1)
}

///|
test "cuckoo filter with minimum bucket size" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert("test"))
  assert_true(filter.contains("test"))
  assert_eq(filter.bucket_size(), 1)
}

///|
test "scalable bloom filter minimum initial capacity" {
  let filter = @src.ScalableBloomFilter::new(1, 0.01)
  assert_eq(filter.slice_count(), 1)
  assert_true(filter.capacity() >= 1)
}

///|
test "scalable counting bloom filter minimum initial capacity" {
  let filter = @src.ScalableCountingBloomFilter::new(1, 0.01)
  assert_eq(filter.slice_count(), 1)
  assert_true(filter.capacity() >= 1)
}

///|
test "concurrent scalable bloom filter minimum initial capacity" {
  let filter = @src.ConcurrentScalableBloomFilter::new(1, 0.01)
  assert_eq(filter.slice_count(), 1)
}

///|
test "concurrent scalable counting bloom filter minimum initial capacity" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(1, 0.01)
  assert_eq(filter.slice_count(), 1)
}

///|
test "bloom filter estimated_item_count respects fill ratio" {
  let filter = @src.BloomFilter::with_size(8192, 5)
  for i = 0; i < 500; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let estimated = filter.estimated_item_count()
  assert_true(estimated > 400.0)
  assert_true(estimated < 600.0)
}

///|
test "counting bloom filter estimated_item_count respects fill ratio" {
  let filter = @src.CountingBloomFilter::with_size(8192, 5)
  for i = 0; i < 500; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let estimated = filter.estimated_item_count()
  assert_true(estimated > 400.0)
  assert_true(estimated < 600.0)
}

///|
test "compact counting bloom filter estimated_item_count respects fill ratio" {
  let filter = @src.CompactCountingBloomFilter::with_size(8192, 5)
  for i = 0; i < 500; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let estimated = filter.estimated_item_count()
  assert_true(estimated > 400.0)
  assert_true(estimated < 600.0)
}

///|
test "scalable bloom filter estimated_item_count sums slices" {
  let filter = @src.ScalableBloomFilter::new(500, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let estimated = filter.estimated_item_count()
  assert_true(filter.slice_count() > 1)
  assert_true(estimated > 900.0)
}

///|
test "scalable counting bloom filter estimated_item_count sums slices" {
  let filter = @src.ScalableCountingBloomFilter::new(500, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  let estimated = filter.estimated_item_count()
  assert_true(filter.slice_count() > 1)
  assert_true(estimated > 900.0)
}

///|
test "bloom filter false_positive_rate is zero when empty" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  assert_eq(filter.false_positive_rate(), 0.0)
}

///|
test "bloom filter false_positive_rate increases as filter fills" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  let initial_rate = filter.false_positive_rate()
  for i = 0; i < 500; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.false_positive_rate() >= initial_rate)
  assert_true(filter.false_positive_rate() > 0.0)
}

///|
test "cuckoo filter load_factor reports correctly" {
  let filter = @src.CuckooFilter::new(100)
  assert_eq(filter.load_factor(), 0.0)
  for i = 0; i < 50; i = i + 1 {
    ignore(filter.insert(i))
  }
  let load = filter.load_factor()
  assert_true(load > 0.0)
  assert_true(load < 1.0)
}

///|
test "concurrent bloom filter count is thread-safe view" {
  let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
  for i = 0; i < 100; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_eq(filter.count(), 100)
}

///|
test "concurrent counting bloom filter count is thread-safe view" {
  let filter = @src.ConcurrentCountingBloomFilter::new(1000, 0.01)
  for i = 0; i < 100; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_eq(filter.count(), 100)
}

///|
test "concurrent cuckoo filter count is thread-safe view" {
  let filter = @src.ConcurrentCuckooFilter::new(100)
  for i = 0; i < 50; i = i + 1 {
    ignore(filter.insert("key-" + i.to_string()))
  }
  assert_eq(filter.count(), 50)
}

///|
test "concurrent bloom filter is_empty reflects last clear" {
  let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
  filter.insert("key")
  assert_false(filter.is_empty())
  filter.clear()
  assert_true(filter.is_empty())
}

///|
test "concurrent counting bloom filter is_empty reflects last clear" {
  let filter = @src.ConcurrentCountingBloomFilter::new(1000, 0.01)
  filter.insert("key")
  assert_false(filter.is_empty())
  filter.clear()
  assert_true(filter.is_empty())
}

///|
test "concurrent cuckoo filter is_empty reflects last clear" {
  let filter = @src.ConcurrentCuckooFilter::new(100)
  ignore(filter.insert("key"))
  assert_false(filter.is_empty())
  filter.clear()
  assert_true(filter.is_empty())
}

///|
test "blocked bloom filter memory_bytes is consistent with bit_count" {
  let filter = @src.BlockedBloomFilter::new(10000, 0.01)
  let expected_bytes = (filter.bit_count() / 512) * 64
  assert_eq(filter.memory_bytes(), expected_bytes.to_int64())
  assert_true(filter.memory_bytes() % 64L == 0L)
}

///|
test "concurrent blocked bloom filter merge with compatible layout" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::new(1000, 0.01)
  concurrent.insert("a")
  let (bits, hashes) = @src.BlockedBloomFilter::optimal_size(1000, 0.01)
  let empty = @src.BlockedBloomFilter::with_size(bits, hashes)
  concurrent.merge(empty)
  assert_true(concurrent.contains("a"))
}

///|
test "concurrent blocked bloom filter union with same layout" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::new(1000, 0.01)
  concurrent.insert("a")
  let other = @src.BlockedBloomFilter::with_size(concurrent.bit_count(), concurrent.hash_count())
  other.insert("b")
  let result = concurrent.union(other)
  assert_true(result.contains("a"))
  assert_true(result.contains("b"))
}

///|
test "scalable bloom filter clear preserves target_rate" {
  let filter = @src.ScalableBloomFilter::new(1000, 0.01)
  for i = 0; i < 2000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  let before = filter.target_false_positive_rate()
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.target_false_positive_rate(), before)
  assert_true(filter.is_empty())
}

///|
test "scalable counting bloom filter clear preserves target_rate" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  for i = 0; i < 200; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  let before = filter.target_false_positive_rate()
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.target_false_positive_rate(), before)
  assert_true(filter.is_empty())
  assert_eq(filter.tracked_key_count(), 0)
}