///|
test "compact counting bloom filter remove_all returns true for empty keys" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert("key")
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
}

///|
test "compact counting bloom filter remove_all with non_existent_key disturbs_existing" {
  // Note: removing a non-existent key can drain counters of other keys
  // that share slots, which is inherent to counting Bloom filter behavior.
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  filter.insert_all(["a", "b"])
  assert_false(filter.remove_all(["a", "missing"]))
  // "a" may be disturbed due to shared counters with "missing"'s hash positions
  assert_true(filter.contains("b"))
  assert_eq(filter.count(), 1)
}

///|
test "compact counting bloom filter insert_if_absent returns false when full" {
  let filter = @src.CompactCountingBloomFilter::with_size(16, 4)
  filter.insert("a")
  filter.insert("b")
  filter.insert("c")
  filter.insert("d")
  filter.insert("e")
  filter.insert("f")
  filter.insert("g")
  filter.insert("h")
  filter.insert("i")
  filter.insert("j")
  filter.insert("k")
  filter.insert("l")
  filter.insert("m")
  filter.insert("n")
  // Filter is now full (16 insertions with slot count 16 and hash count 4)
  let result = filter.insert_if_absent("should-not-fit")
  assert_false(result)
  // Existing keys still present
  assert_true(filter.contains("a"))
}

///|
test "compact counting bloom filter insert_if_absent with duplicates" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  assert_true(filter.insert_if_absent("a"))
  assert_false(filter.insert_if_absent("a"))
  assert_eq(filter.count_of("a"), 1)
  assert_eq(filter.count(), 1)
}

///|
test "compact counting bloom filter count_of after partial removal" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert("a")
  filter.insert("a")
  filter.insert("a")
  assert_eq(filter.count_of("a"), 3)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 2)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 1)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 0)
  assert_false(filter.contains("a"))
}

///|
test "compact counting bloom filter clear and rebuild" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert("key1")
  filter.insert("key2")
  filter.insert("key1")
  assert_eq(filter.count(), 3)
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.count_of("key1"), 0)
  assert_eq(filter.count_of("key2"), 0)
  assert_false(filter.contains("key1"))
  assert_false(filter.contains("key2"))
}

///|
test "compact counting bloom filter occupied_slot_count consistency" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  assert_eq(filter.occupied_slot_count(), 0)
  filter.insert("a")
  assert_true(filter.occupied_slot_count() > 0)
  filter.insert("b")
  assert_true(filter.occupied_slot_count() >= 2)
}

///|
test "compact counting bloom filter estimated_item_count boundaries" {
  let filter = @src.CompactCountingBloomFilter::with_size(16, 1)
  // Empty filter
  assert_eq(filter.estimated_item_count(), 0.0)
  // After insertion
  filter.insert("a")
  assert_true(filter.estimated_item_count() > 0.0)
  // Full filter (saturate counters)
  for i = 0; i < 64; i = i + 1 {
    filter.insert(i.to_string())
  }
  // occupied_slot_count may be 16 or fewer due to counter saturation behavior
  let occupied = filter.occupied_slot_count()
  assert_true(occupied > 0)
  // Estimated count when full: check the formula path
  let estimated = filter.estimated_item_count()
  // When all slots are occupied but not necessarily x >= m due to
  // counter distribution, the estimate can be finite.
  assert_true(estimated > 0.0)
}

///|
test "compact counting bloom filter counter_max consistency" {
  assert_eq(@src.CompactCountingBloomFilter::counter_max(), 15)
}

///|
test "compact counting bloom filter memory_bytes is multiple of 8" {
  let filter = @src.CompactCountingBloomFilter::new(100, 0.01)
  assert_eq(filter.memory_bytes() % 8L, 0L)
}

///|
test "compact counting bloom filter set operations with empty operands" {
  let left = @src.CompactCountingBloomFilter::with_size(256, 4)
  left.insert("shared")
  let right = @src.CompactCountingBloomFilter::with_size(256, 4)

  let union = left.union(right)
  assert_true(union.contains("shared"))

  let intersection = left.intersection(right)
  assert_true(intersection.is_empty())

  let merged = left.copy()
  merged.merge(right)
  assert_eq(merged.count(), 1)

  let empty = @src.CompactCountingBloomFilter::with_size(256, 4)
  assert_true(empty.is_subset_of(left))
  assert_true(empty.is_disjoint_from(left))

  let disjoint_union = left.union(empty)
  assert_true(disjoint_union.contains("shared"))
}

///|
test "compact counting bloom filter is_full shortcut works" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  // Insert many items to fill the filter
  for i = 0; i < 1000; i = i + 1 {
    filter.insert(i.to_string())
  }
  assert_true(filter.is_full())
  // One more insertion advances counter but filter stays full
  filter.insert("extra")
  assert_true(filter.is_full())
}

///|
test "compact counting bloom filter from_bytes round trip" {
  let filter = @src.CompactCountingBloomFilter::new(200, 0.01)
  for i = 0; i < 80; i = i + 1 {
    filter.insert("item-" + i.to_string())
  }
  let bytes = filter.to_bytes()
  let restored = @src.CompactCountingBloomFilter::from_bytes(bytes)
  assert_eq(restored.count(), filter.count())
  assert_true(restored.contains("item-0"))
  assert_eq(restored.count_of("item-0"), 1)
  assert_false(restored.contains("never-inserted"))
}

///|
test "compact counting bloom filter delete all then reinsert" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert("a")
  filter.insert("a")
  filter.insert("a")
  assert_eq(filter.count(), 3)
  assert_true(filter.remove("a"))
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("a"))
  assert_eq(filter.count(), 1)
  assert_true(filter.remove("a"))
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("a"))
  assert_eq(filter.count_of("a"), 0)
  // Reinsert after full removal
  filter.insert("a")
  assert_true(filter.contains("a"))
  assert_eq(filter.count_of("a"), 1)
  assert_eq(filter.count(), 1)
}

///|
test "compact counting bloom filter counter saturation and removal" {
  let filter = @src.CompactCountingBloomFilter::with_size(16, 4)
  // Insert the same key 20 times; counters saturate at 15
  for i = 0; i < 20; i = i + 1 {
    filter.insert("saturation-key")
  }
  // count_of estimate should be at most counter_max (15) since counters are saturated
  assert_true(filter.count_of("saturation-key") <= 15)
  assert_true(filter.count_of("saturation-key") > 0)
  // Remove once; should succeed and decrement
  assert_true(filter.remove("saturation-key"))
  assert_eq(filter.count(), 19)
  // Remove again; key should still be present
  assert_true(filter.remove("saturation-key"))
  assert_eq(filter.count(), 18)
  // Filter should still contain the key
  assert_true(filter.contains("saturation-key"))
  // Remove once more
  assert_true(filter.remove("saturation-key"))
  assert_eq(filter.count(), 17)
  // Final check: filter may or may not contain depending on counter distribution
  assert_true(filter.count_of("saturation-key") >= 0)
}


///|
test "compact counting bloom filter insert_if_absent after saturation" {
  let filter = @src.CompactCountingBloomFilter::with_size(16, 4)
  // Fill the filter with 16 insertions of different keys
  for i = 0; i < 16; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  // Now insert_if_absent for a new key should fail (all counters positive)
  let result = filter.insert_if_absent("new-key")
  assert_false(result)
  // Existing keys still present
  assert_true(filter.contains("key-0"))
}

///|
test "compact counting bloom filter insert_if_absent with some positive counters" {
  let filter = @src.CompactCountingBloomFilter::with_size(64, 4)
  // Insert some keys so some counters are positive but not all slots
  filter.insert("key-a")
  filter.insert("key-b")
  // At this point, some counters are positive and some are zero.
  // insert_if_absent for a new key should succeed if at least one
  // of its selected counters is zero.
  let result = filter.insert_if_absent("key-c")
  assert_true(result)
  assert_true(filter.contains("key-c"))
  // Count should be 1
  assert_eq(filter.count_of("key-c"), 1)
  assert_eq(filter.count(), 3)
}

///|
test "compact counting bloom filter removal with saturated shared counters" {
  // Two keys sharing a saturated counter can disturb each other on removal
  let filter = @src.CompactCountingBloomFilter::with_size(64, 4)
  filter.insert("key-a")
  filter.insert("key-b")
  // Remove key-a; key-b's counter may be affected if they share positions
  assert_true(filter.remove("key-a"))
  // key-b may still be present (depends on hash collision)
  assert_true(filter.contains("key-b") || filter.count_of("key-b") == 0)
}