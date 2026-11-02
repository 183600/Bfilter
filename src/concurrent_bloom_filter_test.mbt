///|
test "concurrent bloom filter insert contains and remove via clear" {
  let filter = @src.ConcurrentBloomFilter::new(200, 0.01)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  filter.insert("alpha")
  filter.insert(42)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 2)
  filter.clear()
  assert_true(filter.is_empty())
  assert_false(filter.contains("alpha"))
}

///|
test "concurrent bloom filter batch operations share one lock" {
  let keys = ["a", "b", "c", "d"]
  let filter = @src.ConcurrentBloomFilter::new(100, 0.001)
  filter.insert_all(keys)
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  assert_false(filter.contains("missing"))
  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_true(filter.contains_all(empty))
  assert_eq(filter.count(), keys.length())
}

///|
test "concurrent bloom filter reports sizing and false positive rate" {
  let filter = @src.ConcurrentBloomFilter::with_size(256, 5)
  assert_eq(filter.bit_count(), 256)
  assert_eq(filter.hash_count(), 5)
  assert_eq(filter.false_positive_rate(), 0.0)
  filter.insert("value")
  let rate = filter.false_positive_rate()
  assert_true(rate > 0.0 && rate < 1.0)
}

///|
test "panic concurrent bloom filter rejects invalid configuration" {
  @src.ConcurrentBloomFilter::new(0, 0.01) |> ignore
}

///|
test "concurrent bloom filter batch conditional inserts track additions" {
  let filter = @src.ConcurrentBloomFilter::with_size(4096, 4)
  let keys = ["a", "b", "c", "d", "e"]
  assert_eq(filter.insert_all_if_absent(keys), keys.length())
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  // Keys already represented are not added again.
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.count(), keys.length())
  // Duplicates within a batch are counted once.
  assert_eq(filter.insert_all_if_absent(["f", "f", "g"]), 2)
  assert_eq(filter.count(), keys.length() + 2)
  assert_true(filter.contains("f"))
  assert_true(filter.contains("g"))
  // An empty batch adds nothing.
  let empty : Array[String] = []
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_eq(filter.count(), keys.length() + 2)
}

///|
test "concurrent bloom filter survives interleaved workload" {
  let filter = @src.ConcurrentBloomFilter::with_size(4096, 4)
  for i = 0; i < 500; i = i + 1 {
    filter.insert("key-" + i.to_string())
    if i % 3 == 0 {
      assert_true(filter.contains("key-" + i.to_string()))
    }
    if i % 7 == 0 {
      let _ = filter.count()
    }
  }
  for i = 0; i < 500; i = i + 1 {
    assert_true(filter.contains("key-" + i.to_string()))
  }
  assert_eq(filter.count(), 500)
}

///|
test "concurrent bloom filter serialization preserves state" {
  let filter = @src.ConcurrentBloomFilter::with_size(1024, 4)
  filter.insert("alpha")
  filter.insert("beta")
  filter.insert("alpha")
  let restored = @src.ConcurrentBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.bit_count(), filter.bit_count())
  assert_eq(restored.hash_count(), filter.hash_count())
  assert_true(restored.contains("alpha"))
  assert_true(restored.contains("beta"))
  restored.insert("gamma")
  assert_eq(restored.count(), 4)
  assert_true(restored.contains("gamma"))
}
