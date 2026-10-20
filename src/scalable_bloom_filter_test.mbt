///|
test "scalable bloom filter grows and keeps every inserted key" {
  let filter = @src.ScalableBloomFilter::new(4, 0.01)
  assert_true(filter.is_empty())
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.capacity(), 4)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_eq(filter.count(), 20)
  assert_eq(filter.slice_count(), 3)
  assert_eq(filter.capacity(), 28)
  for i = 0; i < 20; i = i + 1 {
    assert_true(filter.contains("key-" + i.to_string()))
  }
  assert_false(filter.contains("missing"))
}

///|
test "scalable bloom filter grows for integer keys" {
  let filter = @src.ScalableBloomFilter::new(8, 0.001)
  for i = 0; i < 200; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  for i = 0; i < 200; i = i + 1 {
    assert_true(filter.contains(i))
  }
}

///|
test "scalable bloom filter batch operations span slices" {
  let filter = @src.ScalableBloomFilter::new(2, 0.01)
  let keys = ["a", "b", "c", "d", "e", "f"]
  filter.insert_all(keys)
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains_any(["missing", "e"]))
  assert_false(filter.contains_any(["missing-1", "missing-2"]))
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
}

///|
test "scalable bloom filter insert_if_absent checks older slices" {
  let filter = @src.ScalableBloomFilter::new(2, 0.01)
  assert_true(filter.insert_if_absent("early"))
  filter.insert("fill-1")
  filter.insert("fill-2")
  assert_true(filter.slice_count() > 1)
  assert_false(filter.insert_if_absent("early"))
  assert_true(filter.insert_if_absent("late"))
  assert_eq(filter.count(), 4)
}

///|
test "scalable bloom filter batch conditional insertion" {
  let filter = @src.ScalableBloomFilter::new(2, 0.01)
  let keys = ["a", "b", "c", "d", "e"]
  assert_eq(filter.insert_all_if_absent(keys), 5)
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.count(), 5)
  assert_true(filter.contains_all(keys))
}

///|
test "scalable bloom filter clear restarts from one slice" {
  let filter = @src.ScalableBloomFilter::new(3, 0.01)
  for i = 0; i < 30; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.slice_count(), 1)
  assert_eq(filter.capacity(), 3)
  assert_false(filter.contains(0))
  assert_true(filter.insert_if_absent(0))
}

///|
test "scalable bloom filter copy is independent" {
  let original = @src.ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 10; i = i + 1 {
    original.insert(i)
  }
  let copy = original.copy()
  assert_eq(copy.count(), original.count())
  assert_eq(copy.slice_count(), original.slice_count())
  assert_true(copy.insert_if_absent(99))
  assert_false(original.contains(99))
  copy.clear()
  assert_eq(copy.count(), 0)
  assert_eq(original.count(), 10)
  for i = 0; i < 10; i = i + 1 {
    assert_true(original.contains(i))
  }
}

///|
test "scalable bloom filter reports occupancy and rates" {
  let filter = @src.ScalableBloomFilter::new(10, 0.01)
  assert_eq(filter.target_false_positive_rate(), 0.01)
  assert_eq(filter.set_bit_count(), 0)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_eq(filter.estimated_item_count(), 0.0)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_true(filter.bit_count() > 0)
  assert_true(filter.memory_bytes() > 0L)
  for i = 0; i < 10; i = i + 1 {
    filter.insert("value-" + i.to_string())
  }
  assert_true(filter.set_bit_count() > 0)
  assert_true(filter.fill_ratio() > 0.0 && filter.fill_ratio() <= 1.0)
  assert_true(filter.estimated_item_count() > 0.0)
  assert_true(filter.false_positive_rate() > 0.0)
  assert_true(filter.false_positive_rate() < 1.0)
  assert_eq(filter.memory_bytes(), filter.bit_count().to_int64() / 8L)
}

///|
test "panic scalable bloom filter rejects non-positive expected items" {
  @src.ScalableBloomFilter::new(0, 0.01) |> ignore
}

///|
test "panic scalable bloom filter rejects invalid false positive rate" {
  @src.ScalableBloomFilter::new(10, 0.0) |> ignore
  @src.ScalableBloomFilter::new(10, 1.0) |> ignore
}

///|
test "scalable bloom filter keeps the combined rate near its target" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  assert_true(filter.false_positive_rate() < 0.02)
  let mut false_positives = 0
  for i = 1000; i < 3000; i = i + 1 {
    if filter.contains(i) {
      false_positives = false_positives + 1
    }
  }
  assert_true(false_positives.to_double() / 2000.0 < 0.05)
}
