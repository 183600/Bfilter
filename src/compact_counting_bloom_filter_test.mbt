///|
test "compact counting filter inserts contains and removes keys" {
  let filter = @src.CompactCountingBloomFilter::new(100, 0.01)
  let keys = ["alpha", "beta", "gamma", "delta"]
  for key in keys {
    filter.insert(key)
  }
  assert_eq(filter.count(), keys.length())
  assert_false(filter.is_empty())
  for key in keys {
    assert_true(filter.contains(key))
    assert_eq(filter.count_of(key), 1)
  }
  assert_true(filter.remove("beta"))
  assert_false(filter.contains("beta"))
  assert_true(filter.contains("alpha"))
  assert_false(filter.remove("beta"))
  assert_eq(filter.count(), keys.length() - 1)
}

///|
test "compact counting filter tracks duplicate insertions" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 3)
  for i = 0; i < 5; i = i + 1 {
    filter.insert("repeat")
  }
  assert_eq(filter.count_of("repeat"), 5)
  assert_eq(filter.count(), 5)
  for i = 0; i < 3; i = i + 1 {
    assert_true(filter.remove("repeat"))
  }
  assert_eq(filter.count_of("repeat"), 2)
  assert_true(filter.contains("repeat"))
  assert_eq(filter.count(), 2)
}

///|
test "compact counting filter saturates counters at fifteen" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 2)
  assert_eq(@src.CompactCountingBloomFilter::counter_max(), 15)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("saturated")
  }
  assert_eq(filter.count_of("saturated"), 15)
  assert_eq(filter.count(), 40)
  assert_true(filter.remove("saturated"))
  assert_eq(filter.count_of("saturated"), 14)
  assert_eq(filter.count(), 39)
  for i = 0; i < 20; i = i + 1 {
    ignore(filter.remove("saturated"))
  }
  assert_false(filter.contains("saturated"))
  assert_eq(filter.count(), 25)
}

///|
test "compact counting filter uses four times less memory than counting filter" {
  let compact = @src.CompactCountingBloomFilter::new(1000, 0.01)
  let counting = @src.CountingBloomFilter::new(1000, 0.01)
  assert_eq(compact.slot_count(), counting.slot_count())
  assert_eq(counting.memory_bytes(), compact.memory_bytes() * 4L)
}

///|
test "compact counting filter copy is independent" {
  let original = @src.CompactCountingBloomFilter::new(50, 0.01)
  original.insert("shared")
  let copy = original.copy()
  copy.insert("only-copy")
  assert_true(copy.contains("only-copy"))
  assert_false(original.contains("only-copy"))
  assert_true(original.remove("shared"))
  assert_true(copy.contains("shared"))
}

///|
test "compact counting filter clear resets counters" {
  let filter = @src.CompactCountingBloomFilter::new(50, 0.01)
  filter.insert_all(["a", "b", "c"])
  assert_true(filter.occupied_slot_count() > 0)
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_false(filter.contains("a"))
}

///|
test "compact counting filter reports occupancy and rates" {
  let filter = @src.CompactCountingBloomFilter::new(100, 0.01)
  assert_eq(filter.estimated_item_count(), 0.0)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_true(filter.memory_bytes() > 0L)
  for i = 0; i < 100; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.occupied_slot_count() > 0)
  assert_true(filter.fill_ratio() > 0.0 && filter.fill_ratio() <= 1.0)
  assert_true(filter.estimated_item_count() > 0.0)
  assert_true(filter.false_positive_rate() > 0.0)
  assert_true(filter.false_positive_rate() < 0.05)
  let mut false_positives = 0
  for i = 100; i < 2100; i = i + 1 {
    if filter.contains(i) {
      false_positives = false_positives + 1
    }
  }
  assert_true(false_positives.to_double() / 2000.0 < 0.05)
}

///|
test "panic compact counting filter rejects invalid expected items" {
  @src.CompactCountingBloomFilter::new(0, 0.01) |> ignore
  @src.CompactCountingBloomFilter::new(-3, 0.01) |> ignore
}

///|
test "panic compact counting filter rejects invalid rates" {
  @src.CompactCountingBloomFilter::new(10, 0.0) |> ignore
  @src.CompactCountingBloomFilter::new(10, 1.0) |> ignore
}

///|
test "panic compact counting filter rejects invalid sizes" {
  @src.CompactCountingBloomFilter::with_size(0, 1) |> ignore
  @src.CompactCountingBloomFilter::with_size(16, 0) |> ignore
}

///|
test "compact counting filter remove returns false when counter_mass is zero" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  assert_false(filter.remove("never-inserted"))
}

///|
test "compact counting filter remove_all returns true for empty keys" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  filter.insert("key")
  let empty : Array[String] = []
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains("key"))
}

///|
test "compact counting filter insert_if_absent when all counters saturated" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 2)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("saturated")
  }
  // All counters should be at max (15), insert_if_absent should return false
  assert_false(filter.insert_if_absent("saturated"))
  assert_eq(filter.count_of("saturated"), 15)
  assert_eq(filter.count(), 40)
}

///|
test "compact counting filter remove_all with mixed present/absent keys" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  filter.insert_all(["a", "b", "c"])
  let present = ["a", "c"]
  let all_removed = filter.remove_all(present)
  assert_true(all_removed)
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("b"))
}

///|
test "compact counting filter count_of returns zero for zero counter" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 4)
  assert_eq(filter.count_of("absent-key"), 0)
  assert_eq(filter.count(), 0)
}

///|
test "compact counting filter serialize roundtrip with saturation" {
  let filter = @src.CompactCountingBloomFilter::with_size(256, 2)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("saturated")
  }
  let restored = @src.CompactCountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count_of("saturated"), 15)
  assert_eq(restored.count(), 40)
  assert_true(restored.remove("saturated"))
  assert_eq(restored.count_of("saturated"), 14)
  assert_eq(restored.count(), 39)
}
