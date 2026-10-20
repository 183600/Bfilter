///|
test "concurrent scalable bloom filter insert contains and clear" {
  let filter = @src.ConcurrentScalableBloomFilter::new(10, 0.01)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  filter.insert("alpha")
  filter.insert(42)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 2)
  assert_false(filter.insert_if_absent("alpha"))
  assert_true(filter.insert_if_absent("beta"))
  assert_eq(filter.count(), 3)
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.slice_count(), 1)
  assert_false(filter.contains("alpha"))
}

///|
test "concurrent scalable bloom filter grows during batch inserts" {
  let filter = @src.ConcurrentScalableBloomFilter::new(2, 0.01)
  let keys : Array[String] = []
  for i = 0; i < 50; i = i + 1 {
    keys.push("key-" + i.to_string())
  }
  filter.insert_all(keys)
  assert_true(filter.slice_count() > 1)
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains_any(["missing", "key-49"]))
  assert_false(filter.contains_any(["missing-1", "missing-2"]))
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
}

///|
test "concurrent scalable bloom filter batch conditional inserts" {
  let filter = @src.ConcurrentScalableBloomFilter::new(2, 0.01)
  let keys = ["a", "b", "c", "d", "e", "f"]
  assert_eq(filter.insert_all_if_absent(keys), keys.length())
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.count(), keys.length())
}

///|
test "concurrent scalable bloom filter snapshot is independent" {
  let filter = @src.ConcurrentScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 10; i = i + 1 {
    filter.insert(i)
  }
  let snapshot = filter.snapshot()
  assert_eq(snapshot.count(), filter.count())
  assert_eq(snapshot.slice_count(), filter.slice_count())
  assert_true(filter.insert_if_absent(99))
  assert_false(snapshot.contains(99))
  assert_true(snapshot.insert_if_absent(100))
  assert_false(filter.contains(100))
  snapshot.clear()
  assert_eq(snapshot.count(), 0)
  assert_eq(filter.count(), 11)
}

///|
test "concurrent scalable bloom filter reports statistics" {
  let filter = @src.ConcurrentScalableBloomFilter::new(8, 0.001)
  assert_eq(filter.target_false_positive_rate(), 0.001)
  assert_eq(filter.set_bit_count(), 0)
  assert_eq(filter.fill_ratio(), 0.0)
  assert_eq(filter.estimated_item_count(), 0.0)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_eq(filter.capacity(), 8)
  assert_true(filter.bit_count() > 0)
  assert_true(filter.memory_bytes() > 0L)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("value-" + i.to_string())
  }
  assert_true(filter.slice_count() > 1)
  assert_true(filter.capacity() > 8)
  assert_true(filter.set_bit_count() > 0)
  assert_true(filter.fill_ratio() > 0.0 && filter.fill_ratio() <= 1.0)
  assert_true(filter.estimated_item_count() > 0.0)
  assert_true(filter.false_positive_rate() > 0.0)
  assert_eq(filter.memory_bytes(), filter.bit_count().to_int64() / 8L)
}

///|
test "concurrent scalable bloom filter serializes through the lock" {
  let filter = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 30; i = i + 1 {
    filter.insert(i)
  }
  let restored = @src.ConcurrentScalableBloomFilter::from_bytes(
    filter.to_bytes(),
  )
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.slice_count(), filter.slice_count())
  for i = 0; i < 30; i = i + 1 {
    assert_true(restored.contains(i))
  }
  assert_true(restored.insert_if_absent(1000))
  assert_false(filter.contains(1000))
}

///|
test "panic concurrent scalable bloom filter rejects invalid configuration" {
  @src.ConcurrentScalableBloomFilter::new(0, 0.01) |> ignore
  @src.ConcurrentScalableBloomFilter::new(10, 1.0) |> ignore
}
