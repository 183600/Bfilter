///|
/// Boundary conditions for the ConcurrentCuckooFilter wrapper: partial batch
/// success and remaining_capacity tracking under the lock.

///|
test "concurrent cuckoo filter insert_all partial success fills capacity" {
  // A 1-bucket, 4-slot filter holds at most 4 fingerprints.
  let filter = @src.ConcurrentCuckooFilter::with_size(1, 4)
  assert_eq(filter.remaining_capacity(), 4)
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  ignore(filter.insert("c"))
  assert_eq(filter.remaining_capacity(), 1)
  let result = filter.insert_all(["d", "e", "f"])
  assert_false(result)
  assert_eq(filter.remaining_capacity(), 0)
  assert_true(filter.load_factor() == 1.0)
  assert_true(filter.is_full())
  assert_true(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_true(filter.contains("c"))
}

///|
test "concurrent cuckoo filter insert_all at exact capacity rejects every key" {
  let filter = @src.ConcurrentCuckooFilter::with_size(1, 4)
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  ignore(filter.insert("c"))
  ignore(filter.insert("d"))
  assert_eq(filter.remaining_capacity(), 0)
  assert_true(filter.is_full())
  assert_false(filter.insert_all(["e", "f"]))
  assert_eq(filter.remaining_capacity(), 0)
  assert_false(filter.contains("e"))
  assert_false(filter.contains("f"))
  assert_true(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_true(filter.contains("c"))
  assert_true(filter.contains("d"))
}

///|
test "concurrent cuckoo filter remaining_capacity after remove and reinsert" {
  let filter = @src.ConcurrentCuckooFilter::with_size(4, 4)
  assert_eq(filter.remaining_capacity(), 16)
  for i = 0; i < 8; i = i + 1 {
    ignore(filter.insert("key-" + i.to_string()))
  }
  assert_eq(filter.remaining_capacity(), 8)
  assert_true(filter.remove("key-0"))
  assert_eq(filter.remaining_capacity(), 9)
  assert_true(filter.insert("key-0"))
  assert_eq(filter.remaining_capacity(), 8)
}

///|
test "concurrent cuckoo filter load_factor reaches one at capacity" {
  let filter = @src.ConcurrentCuckooFilter::with_size(1, 4)
  assert_eq(filter.load_factor(), 0.0)
  for i = 0; i < 4; i = i + 1 {
    assert_true(filter.insert("key-" + i.to_string()))
  }
  assert_eq(filter.load_factor(), 1.0)
  assert_true(filter.is_full())
  assert_false(filter.insert("overflow"))
  assert_eq(filter.load_factor(), 1.0)
}
