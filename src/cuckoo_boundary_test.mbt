///|
/// Boundary conditions for the Cuckoo filter: partial batch success,
/// exact-capacity behavior, and capacity-tracking accuracy.

///|
test "cuckoo filter insert_all partial success fills remaining capacity" {
  // A 1-bucket, 4-slot filter holds at most 4 fingerprints.
  let filter = @src.CuckooFilter::with_size(1, 4)
  assert_eq(filter.remaining_capacity(), 4)
  // Insert three keys that fit, then a batch that overfills.
  ignore(filter.insert("a"))
  ignore(filter.insert("b"))
  ignore(filter.insert("c"))
  assert_eq(filter.remaining_capacity(), 1)
  let result = filter.insert_all(["d", "e", "f"])
  assert_false(result)
  // Exactly one of "d", "e", "f" found room; the rest failed without losing
  // any existing entry.
  assert_eq(filter.remaining_capacity(), 0)
  assert_true(filter.load_factor() == 1.0)
  assert_true(filter.is_full())
  assert_true(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_true(filter.contains("c"))
}

///|
test "cuckoo filter insert_all at exact capacity rejects every key" {
  let filter = @src.CuckooFilter::with_size(1, 4)
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
test "cuckoo filter insert_all duplicate keys each consume a slot" {
  // `insert` stores a fingerprint even when it is already present, so
  // duplicate insertions each consume capacity.
  let filter = @src.CuckooFilter::with_size(2, 4)
  assert_eq(filter.capacity(), 8)
  assert_true(filter.insert_all(["dup", "dup", "dup", "dup"]))
  assert_eq(filter.count(), 4)
  assert_eq(filter.remaining_capacity(), 4)
  assert_eq(filter.count_of("dup"), 4)
  assert_true(filter.contains("dup"))
}

///|
test "cuckoo filter remaining_capacity after remove and reinsert" {
  let filter = @src.CuckooFilter::with_size(4, 4)
  assert_eq(filter.remaining_capacity(), 16)
  for i = 0; i < 8; i = i + 1 {
    ignore(filter.insert("key-" + i.to_string()))
  }
  assert_eq(filter.remaining_capacity(), 8)
  assert_true(filter.remove("key-0"))
  assert_eq(filter.remaining_capacity(), 9)
  ignore(filter.insert("key-0"))
  assert_eq(filter.remaining_capacity(), 8)
}
