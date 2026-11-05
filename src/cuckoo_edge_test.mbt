///|
test "cuckoo filter capacity and remaining_capacity" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_eq(filter.capacity(), 64)
  assert_eq(filter.remaining_capacity(), 64)
  ignore(filter.insert("a"))
  assert_eq(filter.remaining_capacity(), 63)
  assert_true(filter.load_factor() < 1.0)
}

///|
test "cuckoo filter insert when full returns false" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert("only"))
  assert_false(filter.insert("also-only"))
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("only"))
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
test "cuckoo filter remove_all empty returns true" {
  let filter = @src.CuckooFilter::with_size(1024, 4)
  ignore(filter.insert("key"))
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
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
test "cuckoo filter false_positive_rate empty is zero" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_eq(filter.false_positive_rate(), 0.0)
}
