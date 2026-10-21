///|
test "new filter is empty until something is inserted" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  assert_true(filter.is_empty())
  assert_false(filter.contains("missing"))
  assert_eq(filter.count(), 0)
  assert_eq(filter.set_bit_count(), 0)
}

///|
test "insert_all keeps membership and the insertion count in sync" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  filter.insert_all(["a", "b", "c"])
  assert_true(filter.contains_all(["a", "b", "c"]))
  assert_false(filter.is_empty())
  assert_eq(filter.count(), 3)
}

///|
test "empty batch helpers keep the filter unchanged" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  let empty : Array[String] = []
  filter.insert_all(empty)
  assert_false(filter.contains_any(empty))
  assert_false(filter.contains_all(["x", "y"]))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "counting filter remove flips membership back" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  filter.insert("key")
  assert_true(filter.contains("key"))
  assert_true(filter.remove("key"))
  assert_false(filter.contains("key"))
  assert_false(filter.remove("key"))
}
