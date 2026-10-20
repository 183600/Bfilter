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
