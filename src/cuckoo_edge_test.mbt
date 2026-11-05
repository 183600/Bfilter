///|
test "cuckoo filter remove_all returns true for empty keys" {
  let filter = @src.CuckooFilter::with_size(1024, 4)
  ignore(filter.insert("key"))
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
}

///|
test "cuckoo filter remove_all partial failure" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  // Remove one existing and one non-existent
  assert_false(filter.remove_all(["a", "missing"]))
  // "b" should still be present
  assert_true(filter.contains("b"))
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo filter remove_all preserves existing entries when all missing" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  ignore(filter.insert("a"))
  // Remove only non-existent keys
  assert_false(filter.remove_all(["missing1", "missing2"]))
  // "a" should still be present
  assert_true(filter.contains("a"))
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo filter remove_all on full filter preserves existing entries" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert("only"))
  assert_false(filter.remove_all(["other1", "other2"]))
  assert_true(filter.contains("only"))
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo filter insert_if_absent rejects already-present key" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_true(filter.insert("key"))
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo filter insert_if_absent when full returns false" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert("only"))
  assert_false(filter.insert_if_absent("also-only")) // filter is full
  assert_eq(filter.count(), 1)
}

///|
test "cuckoo filter contains_all empty returns true" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
}

///|
test "cuckoo filter contains_any empty returns false" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  let empty : Array[String] = []
  assert_false(filter.contains_any(empty))
}

///|
test "cuckoo filter is_subset_of empty returns true" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  let empty = @src.CuckooFilter::with_size(16, 4)
  assert_true(filter.is_subset_of(empty))
}

///|
test "cuckoo filter is_disjoint_from empty returns true" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  let other = @src.CuckooFilter::with_size(16, 4)
  assert_true(filter.is_disjoint_from(other))
}

///|
test "cuckoo filter count_of returns correct values" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_true(filter.insert("a"))
  assert_true(filter.insert("a"))
  assert_true(filter.insert("b"))
  assert_eq(filter.count_of("a"), 2)
  assert_eq(filter.count_of("b"), 1)
  assert_eq(filter.count(), 3)
}

///|
test "cuckoo filter count_of empty filter returns zero" {
  let filter = @src.CuckooFilter::new(100)
  assert_eq(filter.count_of("anything"), 0)
}

///|
test "cuckoo filter from_bytes round trip preserves membership" {
  let filter = @src.CuckooFilter::new(64)
  assert_true(filter.insert("alpha"))
  assert_true(filter.insert("beta"))
  let bytes = filter.to_bytes()
  let restored = @src.CuckooFilter::from_bytes(bytes)
  assert_true(restored.contains("alpha"))
  assert_true(restored.contains("beta"))
  assert_eq(restored.count(), 2)
  assert_eq(restored.count_of("alpha"), 1)
  assert_eq(restored.count_of("beta"), 1)
}

///|
test "cuckoo filter to_bytes identity" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  let bytes = filter.to_bytes()
  let restored = @src.CuckooFilter::from_bytes(bytes)
  assert_eq(restored.bucket_count(), filter.bucket_count())
  assert_eq(restored.bucket_size(), filter.bucket_size())
  assert_eq(restored.count(), filter.count())
}

///|
test "cuckoo filter load_factor after insertions" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_eq(filter.load_factor(), 0.0)
  ignore(filter.insert("a"))
  assert_true(filter.load_factor() > 0.0)
  ignore(filter.insert("b"))
  assert_true(filter.load_factor() < 1.0)
}

///|
test "cuckoo filter false_positive_rate empty is zero" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_eq(filter.false_positive_rate(), 0.0)
}

///|
test "cuckoo filter capacity and remaining_capacity" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_eq(filter.capacity(), 64) // 16 buckets * 4 slots
  assert_eq(filter.remaining_capacity(), 64)
  ignore(filter.insert("a"))
  assert_eq(filter.remaining_capacity(), 63)
  assert_true(filter.load_factor() < 1.0)
}