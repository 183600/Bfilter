///|
test "bloom filter new filter is empty" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.bit_count() % 64, 0)
  assert_true(filter.hash_count() > 0)
}

///|
test "bloom filter contains inserted values" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  assert_eq(filter.count(), 1000)
  assert_false(filter.is_empty())
  for i = 0; i < 1000; i = i + 1 {
    assert_true(filter.contains("key-" + i.to_string()))
  }
}

///|
test "bloom filter supports integers and batch operations" {
  let keys = [1, 2, 3, 4, 5]
  let filter = @src.BloomFilter::new(100, 0.001)
  filter.insert_all(keys)
  assert_true(filter.contains_all(keys))
  assert_eq(filter.count(), 5)
}

///|
test "bloom filter clear resets all bits and count" {
  let filter = @src.BloomFilter::with_size(128, 3)
  filter.insert("alpha")
  filter.insert("beta")
  assert_eq(filter.count(), 2)
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("alpha"))
  assert_false(filter.contains("beta"))
}

///|
test "bloom filter with_size rounds up to whole words" {
  let filter = @src.BloomFilter::with_size(65, 4)
  assert_eq(filter.bit_count(), 128)
  assert_eq(filter.hash_count(), 4)
  filter.insert("value")
  assert_true(filter.contains("value"))
}

///|
test "bloom filter false positive rate is zero when empty" {
  let filter = @src.BloomFilter::new(10, 0.1)
  assert_eq(filter.false_positive_rate(), 0.0)
}

///|
test "panic bloom filter rejects non-positive expected items" {
  @src.BloomFilter::new(0, 0.01) |> ignore
}

///|
test "panic bloom filter rejects invalid false positive rate" {
  @src.BloomFilter::new(10, 1.0) |> ignore
}

///|
test "panic bloom filter rejects non-positive size" {
  @src.BloomFilter::with_size(0, 1) |> ignore
}

///|
test "bloom filter empty filter misses and empty batches are neutral" {
  let filter = @src.BloomFilter::new(10, 0.01)
  assert_false(filter.contains("missing"))
  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_eq(filter.count(), 0)
  assert_true(filter.contains_all(empty))
}

///|
test "bloom filter false positive rate stays in range as it fills" {
  let filter = @src.BloomFilter::new(100, 0.01)
  let mut previous = 0.0
  for i = 0; i < 100; i = i + 1 {
    filter.insert("value-" + i.to_string())
    let rate = filter.false_positive_rate()
    assert_true(rate >= 0.0 && rate <= 1.0)
    assert_true(rate >= previous)
    previous = rate
  }
}
