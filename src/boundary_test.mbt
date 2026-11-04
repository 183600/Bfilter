///|
test "bloom filter optimal_size returns consistent layout" {
  let (bits, hashes) = @src.BloomFilter::optimal_size(10_000, 0.01)
  let filter = @src.BloomFilter::with_size(bits, hashes)
  assert_eq(bits, filter.bit_count())
  assert_eq(hashes, filter.hash_count())
}

///|
test "bloom filter contains_all returns true for empty keys" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("present")
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
}

///|
test "bloom filter contains_any returns false for empty keys" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("present")
  let empty : Array[String] = []
  assert_false(filter.contains_any(empty))
}

///|
test "counting bloom filter optimal_size returns consistent layout" {
  let (slots, hashes) = @src.CountingBloomFilter::optimal_size(10_000, 0.01)
  let filter = @src.CountingBloomFilter::with_size(slots, hashes)
  assert_eq(slots, filter.slot_count())
  assert_eq(hashes, filter.hash_count())
}

///|
test "counting bloom filter set operations with empty operands short-circuit" {
  let left = @src.CountingBloomFilter::with_size(256, 4)
  left.insert("key")
  let empty = @src.CountingBloomFilter::with_size(256, 4)

  let union = left.union(empty)
  assert_eq(union.count(), 1)
  assert_true(empty.is_subset_of(left))

  let intersection = left.intersection(empty)
  assert_true(intersection.is_empty())

  let merged = left.copy()
  merged.merge(empty)
  assert_eq(merged.count(), 1)
}

///|
test "compact counting bloom filter optimal_size returns consistent layout" {
  let filter = @src.CompactCountingBloomFilter::new(10_000, 0.01)
  let slots = filter.slot_count()
  let hashes = filter.hash_count()
  assert_true(slots % 16 == 0)
  assert_true(hashes > 0)
}

///|
test "compact counting bloom filter is_empty returns true after clear" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert("key")
  assert_false(filter.is_empty())
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "compact counting bloom filter remove_all returns true for empty keys" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert("key")
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
}

///|
test "blocked bloom filter optimal_size returns consistent layout" {
  let (bits, hashes) = @src.BlockedBloomFilter::optimal_size(10_000, 0.01)
  let filter = @src.BlockedBloomFilter::with_size(bits, hashes)
  assert_eq(bits, filter.bit_count())
  assert_eq(bits % 512, 0)
  assert_eq(hashes, filter.hash_count())
}

///|
test "blocked bloom filter block_count matches bit_count" {
  let filter = @src.BlockedBloomFilter::new(10_000, 0.01)
  assert_eq(filter.block_count(), filter.bit_count() / 512)
}

///|
test "blocked bloom filter set operations with empty operands" {
  let left = @src.BlockedBloomFilter::with_size(512, 4)
  left.insert("shared")

  let empty = @src.BlockedBloomFilter::with_size(512, 4)
  assert_true(empty.is_subset_of(left))
  assert_true(empty.is_disjoint_from(left))

  let union = left.union(empty)
  assert_true(union.contains("shared"))
}

///|
test "cuckoo filter contains_all returns true for empty keys" {
  let filter = @src.CuckooFilter::with_size(1024, 4)
  ignore(filter.insert("present"))
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
}

///|
test "cuckoo filter contains_any returns false for empty keys" {
  let filter = @src.CuckooFilter::with_size(1024, 4)
  ignore(filter.insert("present"))
  let empty : Array[String] = []
  assert_false(filter.contains_any(empty))
}

///|
test "cuckoo filter remove_all returns true for empty keys" {
  let filter = @src.CuckooFilter::with_size(1024, 4)
  ignore(filter.insert("key"))
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
}

///|
test "scalable bloom filter optimal_size returns consistent layout" {
  let (bits, hashes) = @src.ScalableBloomFilter::optimal_size(10_000, 0.01)
  assert_true(bits > 0)
  assert_true(hashes > 0)
}

///|
test "scalable bloom filter clear resets to initial capacity" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  for i = 0; i < 200; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "scalable bloom filter set operations with empty operands" {
  let left = @src.ScalableBloomFilter::new(100, 0.01)
  left.insert("key")

  let empty = @src.ScalableBloomFilter::new(100, 0.01)
  assert_true(empty.is_subset_of(left))

  let union = left.union(empty)
  assert_true(union.contains("key"))

  let intersection = left.intersection(empty)
  assert_true(intersection.is_empty())
}

///|
test "scalable counting bloom filter optimal_size returns consistent layout" {
  let (slots, hashes) = @src.ScalableCountingBloomFilter::optimal_size(10_000, 0.01)
  assert_true(slots > 0)
  assert_true(hashes > 0)
}

///|
test "scalable counting bloom filter clear resets to empty" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  for i = 0; i < 200; i = i + 1 {
    let key = "key-" + i.to_string()
    filter.insert(key)
  }
  assert_true(filter.slice_count() > 1)
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.tracked_key_count(), 0)
}

///|
test "scalable counting bloom filter remove_all handles tracked keys" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("a")
  filter.insert("b")
  filter.insert("c")

  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_eq(filter.count(), 3)
}

///|
test "concurrent bloom filter clear works correctly" {
  let filter = @src.ConcurrentBloomFilter::new(100, 0.01)
  filter.insert("key")
  assert_false(filter.is_empty())
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "concurrent bloom filter set operations with empty operands" {
  let left = @src.ConcurrentBloomFilter::new(100, 0.01)
  left.insert("key")

  let right = @src.BloomFilter::with_size(left.bit_count(), left.hash_count())
  let union = left.union(right)
  assert_true(union.contains("key"))
}

///|
test "bloom filter false_positive_rate is zero for empty filter" {
  let filter = @src.BloomFilter::new(100, 0.01)
  assert_eq(filter.false_positive_rate(), 0.0)
}

///|
test "bloom filter fill_ratio is zero for empty filter" {
  let filter = @src.BloomFilter::new(100, 0.01)
  assert_eq(filter.fill_ratio(), 0.0)
}

///|
test "bloom filter estimated_item_count returns zero for empty filter" {
  let filter = @src.BloomFilter::new(100, 0.01)
  assert_eq(filter.estimated_item_count(), 0.0)
}

///|
test "bloom filter is_subset_of is reflexive" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("a")
  filter.insert("b")
  assert_true(filter.is_subset_of(filter))
}

///|
test "bloom filter is_disjoint_from is reflexive false" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("a")
  assert_false(filter.is_disjoint_from(filter))
}

///|
test "counting bloom filter is_empty after clear" {
  let filter = @src.CountingBloomFilter::new(100, 0.01)
  filter.insert("key")
  ignore(filter.remove("key"))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "counting bloom filter remove_all returns true for empty array" {
  let filter = @src.CountingBloomFilter::with_size(256, 4)
  filter.insert("key")
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
}

///|
test "counting bloom filter is_full shortcut works" {
  let filter = @src.CountingBloomFilter::with_size(16, 8)
  filter.insert("a")
  filter.insert("b")
  assert_false(filter.is_full())
}

///|
test "bloom filter merge into empty copies storage" {
  let empty = @src.BloomFilter::with_size(1024, 4)
  let other = @src.BloomFilter::with_size(1024, 4)
  other.insert("key")
  empty.merge(other)
  assert_true(empty.contains("key"))
}

///|
test "blocked bloom filter merge into empty copies storage" {
  let empty = @src.BlockedBloomFilter::with_size(1024, 4)
  let other = @src.BlockedBloomFilter::with_size(1024, 4)
  other.insert("key")
  empty.merge(other)
  assert_true(empty.contains("key"))
}

///|
test "bloom filter memory_bytes is multiple of 8" {
  let filter = @src.BloomFilter::new(100, 0.01)
  assert_eq(filter.memory_bytes() % 8L, 0L)
}

///|
test "blocked bloom filter memory_bytes is multiple of 64" {
  let filter = @src.BlockedBloomFilter::new(100, 0.01)
  assert_eq(filter.memory_bytes() % 64L, 0L)
}

///|
test "cuckoo filter capacity is power of two multiple" {
  let filter = @src.CuckooFilter::new(100)
  let bc = filter.bucket_count()
  assert_true((bc & (bc - 1)) == 0)
}

///|
test "cuckoo filter memory_bytes equals bucket_count * bucket_size" {
  let filter = @src.CuckooFilter::new(100)
  let bc = filter.bucket_count()
  let bs = filter.bucket_size().to_int64()
  assert_eq(filter.memory_bytes(), bc.to_int64() * bs)
}

///|
test "cuckoo filter false_positive_rate is zero for empty filter" {
  let filter = @src.CuckooFilter::new(100)
  assert_eq(filter.false_positive_rate(), 0.0)
}

///|
test "cuckoo filter load_factor is zero for empty filter" {
  let filter = @src.CuckooFilter::new(100)
  assert_eq(filter.load_factor(), 0.0)
}

///|
test "cuckoo filter is_empty after clear" {
  let filter = @src.CuckooFilter::new(100)
  ignore(filter.insert("key"))
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "bloom filter hash_count is at least 1" {
  let filter = @src.BloomFilter::new(100, 0.5)
  assert_true(filter.hash_count() >= 1)
}

///|
test "counting bloom filter hash_count is at least 1" {
  let filter = @src.CountingBloomFilter::new(100, 0.5)
  assert_true(filter.hash_count() >= 1)
}

///|
test "compact counting bloom filter hash_count is at least 1" {
  let filter = @src.CompactCountingBloomFilter::new(100, 0.5)
  assert_true(filter.hash_count() >= 1)
}

///|
test "compact counting bloom filter set operations with empty operands" {
  let left = @src.CompactCountingBloomFilter::with_size(256, 4)
  let right = @src.CompactCountingBloomFilter::with_size(256, 4)
  left.insert("shared")
  right.insert("shared")
  assert_true(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_false(left.is_disjoint_from(right))
  
  let empty = @src.CompactCountingBloomFilter::with_size(256, 4)
  assert_true(empty.is_subset_of(left))
  assert_true(empty.is_disjoint_from(left))
  
  let union = left.union(empty)
  assert_true(union.contains("shared"))
  
  let intersection = left.intersection(empty)
  assert_true(intersection.is_empty())
}

///|
test "blocked bloom filter hash_count is at least 1" {
  let filter = @src.BlockedBloomFilter::new(100, 0.5)
  assert_true(filter.hash_count() >= 1)
}

///|
test "bloom filter copy preserves membership" {
  let original = @src.BloomFilter::new(100, 0.01)
  original.insert("a")
  original.insert("b")
  original.insert("c")
  
  let copy = original.copy()
  assert_true(copy.contains("a"))
  assert_true(copy.contains("b"))
  assert_true(copy.contains("c"))
  
  original.insert("d")
  assert_false(copy.contains("d"))
}

///|
test "counting bloom filter copy is independent" {
  let original = @src.CountingBloomFilter::new(100, 0.01)
  original.insert("key")
  original.insert("key")
  
  let copy = original.copy()
  assert_eq(copy.count_of("key"), 2)
  
  original.insert("other")
  assert_eq(original.count(), 3)
  assert_eq(copy.count(), 2)
}

///|
test "cuckoo filter copy is independent from original" {
  let original = @src.CuckooFilter::new(100)
  ignore(original.insert("key1"))
  ignore(original.insert("key2"))
  
  let copy = original.copy()
  assert_true(copy.contains("key1"))
  assert_true(copy.contains("key2"))
  
  ignore(original.insert("key3"))
  assert_true(original.contains("key3"))
  assert_false(copy.contains("key3"))
}

///|
test "scalable bloom filter copy preserves all slices" {
  let original = @src.ScalableBloomFilter::new(100, 0.01)
  for i = 0; i < 500; i = i + 1 {
    original.insert(i)
  }
  
  let copy = original.copy()
  assert_eq(copy.count(), original.count())
  assert_eq(copy.slice_count(), original.slice_count())
  
  for i = 0; i < 100; i = i + 1 {
    assert_true(copy.contains(i))
  }
}