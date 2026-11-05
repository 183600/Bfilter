///|
test "bloom filter contains_any returns true when any key is present" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present", "other"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "counting bloom filter contains_any returns true when any key is present" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "compact counting bloom filter contains_any with present key" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "blocked bloom filter contains_any with present key" {
  let filter = @src.BlockedBloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "cuckoo filter contains_any with present key" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  ignore(filter.insert("present"))
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "scalable bloom filter contains_any with present key" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "scalable counting bloom filter contains_any with present key" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "concurrent bloom filter contains_any with present key" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "concurrent counting bloom filter contains_any with present key" {
  let filter = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "concurrent compact counting bloom filter contains_any with present key" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "concurrent blocked bloom filter contains_any with present key" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  filter.insert("present")
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

///|
test "concurrent cuckoo filter contains_any with present key" {
  let filter = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(filter.insert("present"))
  assert_true(filter.contains_any(["absent", "present"]))
  assert_false(filter.contains_any(["absent1", "absent2"]))
}

//

///|
test "bloom filter is_subset_of is symmetric for identical filters" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("a")
  filter.insert("b")
  assert_true(filter.is_subset_of(filter))
  let copy = filter.copy()
  assert_true(filter.is_subset_of(copy))
  assert_true(copy.is_subset_of(filter))
}

///|
test "bloom filter is_disjoint_from is reflexive false" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("a")
  assert_false(filter.is_disjoint_from(filter))
}

///|
test "bloom filter merge preserves existing membership" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("preserve")
  filter.insert("keep")
  let other = @src.BloomFilter::with_size(1024, 4)
  other.insert("add")
  filter.merge(other)
  assert_true(filter.contains("preserve"))
  assert_true(filter.contains("keep"))
  assert_true(filter.contains("add"))
}

///|
test "counting bloom filter merge preserves multiplicities" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  filter.insert("a")
  filter.insert("a")
  let other = @src.CountingBloomFilter::with_size(1024, 4)
  other.insert("a")
  filter.merge(other)
  assert_eq(filter.count_of("a"), 2)
}

///|
test "bloom filter memory_bytes equals bit_count / 8" {
  let filter = @src.BloomFilter::with_size(64, 4)
  assert_eq(filter.memory_bytes(), 8)
}

///|
test "bloom filter memory_bytes is multiple of 8" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  assert_eq(filter.memory_bytes(), 128)
}

///|
test "bloom filter set_bit_count after inserts" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert("a")
  filter.insert("b")
  let bits = filter.set_bit_count()
  assert_true(bits >= 8)
  assert_true(bits <= 16)
}