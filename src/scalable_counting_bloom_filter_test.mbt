///|
test "scalable counting bloom filter grows and tracks multiplicity" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  assert_true(filter.is_empty())
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.capacity(), 4L)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_eq(filter.count(), 20)
  assert_eq(filter.tracked_key_count(), 20)
  assert_eq(filter.slice_count(), 3)
  assert_eq(filter.capacity(), 28L)
  filter.insert("key-0")
  filter.insert("key-0")
  assert_eq(filter.count(), 22)
  assert_eq(filter.count_of("key-0"), 3)
  assert_eq(filter.slice_count(), 3)
  for i = 0; i < 20; i = i + 1 {
    assert_true(filter.contains("key-" + i.to_string()))
  }
  assert_false(filter.contains("missing"))
}

///|
test "scalable counting bloom filter removes individual occurrences" {
  let filter = @src.ScalableCountingBloomFilter::new(16, 0.001)
  filter.insert("a")
  filter.insert("a")
  filter.insert("a")
  filter.insert("b")
  assert_eq(filter.tracked_key_count(), 2)
  assert_eq(filter.count_of("a"), 3)
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 2)
  assert_eq(filter.count(), 3)
  assert_true(filter.contains("a"))
  assert_true(filter.remove("a"))
  assert_true(filter.remove("a"))
  assert_eq(filter.count_of("a"), 0)
  assert_false(filter.contains("a"))
  assert_false(filter.remove("a"))
  assert_false(filter.remove("missing"))
  assert_eq(filter.tracked_key_count(), 1)
  assert_true(filter.contains("b"))
  assert_eq(filter.count(), 1)
}

///|
test "scalable counting bloom filter batch operations and conditional insertion" {
  let filter = @src.ScalableCountingBloomFilter::new(2, 0.01)
  let keys = ["a", "b", "c", "d", "e", "f"]
  assert_eq(filter.insert_all_if_absent(keys), 6)
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains_any(["missing", "e"]))
  assert_eq(filter.count_of("missing-1"), 0)
  assert_eq(filter.insert_all_if_absent(["a", "g"]), 1)
  assert_eq(filter.count_of("a"), 1)
  assert_true(filter.insert_if_absent("h"))
  assert_false(filter.insert_if_absent("a"))
  assert_false(filter.remove_all(["a", "b", "missing"]))
  assert_eq(filter.count_of("a"), 0)
  assert_eq(filter.count_of("b"), 0)
  assert_true(filter.remove_all(["c", "d", "e", "f", "g", "h"]))
  assert_eq(filter.count(), 0)
  assert_true(filter.is_empty())
}

///|
test "scalable counting bloom filter copy and clear are independent" {
  let original = @src.ScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 10; i = i + 1 {
    original.insert(i)
  }
  let copy = original.copy()
  assert_eq(copy.count(), original.count())
  assert_eq(copy.tracked_key_count(), original.tracked_key_count())
  assert_eq(copy.slice_count(), original.slice_count())
  assert_true(copy.remove(3))
  assert_eq(copy.count_of(3), 0)
  assert_eq(original.count_of(3), 1)
  assert_true(original.contains(3))
  copy.clear()
  assert_eq(copy.count(), 0)
  assert_eq(copy.tracked_key_count(), 0)
  assert_eq(copy.slice_count(), 1)
  assert_false(copy.contains(0))
  assert_eq(original.count(), 10)
  for i = 0; i < 10; i = i + 1 {
    assert_true(original.contains(i))
  }
}

///|
test "scalable counting bloom filter reports occupancy and rates" {
  let filter = @src.ScalableCountingBloomFilter::new(10, 0.01)
  assert_eq(filter.target_false_positive_rate(), 0.01)
  assert_eq(filter.occupied_slot_count(), 0L)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_eq(filter.estimated_item_count(), 0.0)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_true(filter.slot_count() > 0L)
  assert_true(filter.memory_bytes() > 0L)
  for i = 0; i < 10; i = i + 1 {
    filter.insert("value-" + i.to_string())
  }
  assert_true(filter.occupied_slot_count() > 0L)
  assert_true(filter.fill_ratio() > 0.0 && filter.fill_ratio() <= 1.0)
  assert_true(filter.estimated_item_count() > 0.0)
  assert_true(filter.false_positive_rate() > 0.0)
  assert_true(filter.false_positive_rate() < 1.0)
  assert_eq(filter.memory_bytes(), filter.slot_count() * 2L)
}

///|
test "panic scalable counting bloom filter rejects non-positive expected items" {
  @src.ScalableCountingBloomFilter::new(0, 0.01) |> ignore
}

///|
test "panic scalable counting bloom filter rejects zero false positive rate" {
  @src.ScalableCountingBloomFilter::new(10, 0.0) |> ignore
}

///|
test "panic scalable counting bloom filter rejects unit false positive rate" {
  @src.ScalableCountingBloomFilter::new(10, 1.0) |> ignore
}

///|
test "scalable counting bloom filter removes keys from older slices" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.0001)
  filter.insert("old")
  filter.insert("old")
  for i = 0; i < 40; i = i + 1 {
    filter.insert("fill-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  assert_true(filter.contains("old"))
  assert_eq(filter.count_of("old"), 2)
  assert_true(filter.remove("old"))
  assert_true(filter.remove("old"))
  assert_eq(filter.count_of("old"), 0)
  assert_false(filter.remove("old"))
  assert_false(filter.contains("old"))
  for i = 0; i < 40; i = i + 1 {
    assert_true(filter.contains("fill-" + i.to_string()))
  }
}
