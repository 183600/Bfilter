///|
test "counting bloom filter insert contains and remove" {
  let filter = @src.CountingBloomFilter::new(100, 0.01)
  assert_true(filter.is_empty())
  filter.insert("alpha")
  assert_true(filter.contains("alpha"))
  assert_eq(filter.count(), 1)
  assert_true(filter.remove("alpha"))
  assert_false(filter.contains("alpha"))
  assert_true(filter.is_empty())
  assert_false(filter.remove("alpha"))
}

///|
test "counting bloom filter tracks duplicate insertions" {
  let filter = @src.CountingBloomFilter::with_size(128, 3)
  filter.insert("same")
  filter.insert("same")
  filter.insert("same")
  assert_eq(filter.count(), 3)
  assert_true(filter.remove("same"))
  assert_true(filter.contains("same"))
  assert_true(filter.remove("same"))
  assert_true(filter.contains("same"))
  assert_true(filter.remove("same"))
  assert_false(filter.contains("same"))
  assert_eq(filter.count(), 0)
}

///|
test "counting bloom filter batch operations and clear" {
  let keys = ["a", "b", "c"]
  let filter = @src.CountingBloomFilter::new(50, 0.001)
  filter.insert_all(keys)
  assert_true(filter.contains_all(keys))
  assert_true(filter.remove_all(keys))
  assert_true(filter.is_empty())
  filter.insert("a")
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("a"))
}

///|
test "counting bloom filter rounds slot count to counter words" {
  let filter = @src.CountingBloomFilter::with_size(17, 2)
  assert_eq(filter.slot_count(), 32)
  assert_eq(filter.hash_count(), 2)
  filter.insert("value")
  assert_true(filter.contains("value"))
}

///|
test "counting bloom filter false positive rate is zero when empty" {
  let filter = @src.CountingBloomFilter::new(10, 0.1)
  assert_eq(filter.false_positive_rate(), 0.0)
}

///|
test "panic counting bloom filter rejects non-positive expected items" {
  @src.CountingBloomFilter::new(0, 0.01) |> ignore
}

///|
test "panic counting bloom filter rejects invalid false positive rate" {
  @src.CountingBloomFilter::new(10, 0.0) |> ignore
}

///|
test "panic counting bloom filter rejects non-positive size" {
  @src.CountingBloomFilter::with_size(0, 1) |> ignore
}

///|
test "counting bloom filter survives many duplicate insertions" {
  let filter = @src.CountingBloomFilter::with_size(64, 2)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("same")
  }
  assert_eq(filter.count(), 20)
  for i = 0; i < 20; i = i + 1 {
    assert_true(filter.remove("same"))
  }
  assert_true(filter.is_empty())
  assert_false(filter.contains("same"))
}
