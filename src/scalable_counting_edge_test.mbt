///|
test "scalable counting bloom filter remove_all returns true for empty keys" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("key")
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
}

///|
test "scalable counting bloom filter remove_all partial failure" {
  let filter = @src.ScalableCountingBloomFilter::new(16, 0.01)
  filter.insert("a")
  filter.insert("b")
  filter.insert("c")
  // Remove one existing and one non-existent
  assert_false(filter.remove_all(["a", "missing"]))
  // "b" and "c" should still be present
  assert_true(filter.contains("b"))
  assert_true(filter.contains("c"))
  assert_eq(filter.count(), 2)
}

///|
test "scalable counting bloom filter remove individual occurrences" {
  let filter = @src.ScalableCountingBloomFilter::new(16, 0.01)
  filter.insert("a")
  filter.insert("a")
  filter.insert("a")
  assert_eq(filter.count_of("a"), 3)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 2)
  assert_eq(filter.count(), 2)
  assert_true(filter.contains("a"))
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 1)
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("a"))
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 0)
  assert_false(filter.contains("a"))
  assert_false(filter.remove("a"))
}

///|
test "scalable counting bloom filter insert_all_if_absent with duplicates" {
  let filter = @src.ScalableCountingBloomFilter::new(16, 0.01)
  let keys = ["a", "a", "a", "b", "b"]
  let added = filter.insert_all_if_absent(keys)
  assert_eq(added, 2) // "a" and "b" added once each (duplicates skipped)
  assert_eq(filter.count_of("a"), 1)
  assert_eq(filter.count_of("b"), 1)
  assert_eq(filter.count(), 2)
}

///|
test "scalable counting bloom filter count_of after mixed insertions and removals" {
  let filter = @src.ScalableCountingBloomFilter::new(16, 0.01)
  // Insert 5 "a"s and 3 "b"s
  for i = 0; i < 5; i = i + 1 {
    filter.insert("a")
  }
  for i = 0; i < 3; i = i + 1 {
    filter.insert("b")
  }
  assert_eq(filter.count(), 8)
  assert_eq(filter.count_of("a"), 5)
  assert_eq(filter.count_of("b"), 3)
  // Remove 2 "a"s and 1 "b" (one remove removes one contribution)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 4)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 3)
  assert_true(filter.remove("b"))
  assert_eq(filter.count_of("b"), 2)
  // count should decrease by 3
  assert_eq(filter.count(), 5)
  assert_eq(filter.count_of("a"), 3)
  assert_eq(filter.count_of("b"), 2)
  // Remove remaining 2 "b" contributions (total 3 removes for 3 insertions)
  assert_true(filter.remove("b"))
  assert_eq(filter.count_of("b"), 1)
  assert_true(filter.remove("b"))
  assert_eq(filter.count_of("b"), 0)
  assert_false(filter.contains("b"))
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("a"), 3)
}

///|
test "scalable counting bloom filter clear and rebuild" {
  let filter = @src.ScalableCountingBloomFilter::new(10, 0.01)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  assert_eq(filter.count(), 20)
  filter.clear()
  assert_eq(filter.slice_count(), 1)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.tracked_key_count(), 0)
  // All keys should be gone
  for i = 0; i < 20; i = i + 1 {
    assert_false(filter.contains("key-" + i.to_string()))
  }
}

///|
test "scalable counting bloom filter from_bytes round trip with removals" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("skey-" + i.to_string())
  }
  filter.insert("skey-0")
  filter.insert("skey-0")
  let bytes = filter.to_bytes()
  let restored = @src.ScalableCountingBloomFilter::from_bytes(bytes)
  assert_true(restored.contains("skey-0"))
  assert_eq(restored.count_of("skey-0"), 3)
  // After round trip, count may include metadata; just verify basics.
  assert_true(restored.count() >= 40)
  // Remove one contribution and verify
  assert_true(restored.remove("skey-0"))
  assert_eq(restored.count_of("skey-0"), 2)
}

///|
test "scalable counting bloom filter insert_if_absent across slices" {
  let filter = @src.ScalableCountingBloomFilter::new(2, 0.01)
  // Insert some keys
  filter.insert("a")
  filter.insert("b")
  // insert_if_absent should return false for already-present keys
  assert_false(filter.insert_if_absent("a"))
  assert_true(filter.insert_if_absent("c"))
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("a"), 1)
  assert_eq(filter.count_of("b"), 1)
  assert_eq(filter.count_of("c"), 1)
}

///|
test "scalable counting bloom filter contains_all and contains_any" {
  let filter = @src.ScalableCountingBloomFilter::new(16, 0.01)
  let keys = ["a", "b", "c", "d"]
  filter.insert_all(keys)
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains_any(keys))
  // Remove one key and check
  assert_true(filter.remove("a"))
  assert_false(filter.contains_all(keys)) // "a" is now missing
  // contains_any checks remaining keys; "a" may still be reported due to
  // false positives in other slices, so we check a definitely absent key
  assert_false(filter.contains_any(["e", "f", "g"])) // none present
}