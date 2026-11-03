///|
test "counting filter remove_all continues after false positive removal fails" {
  let filter = @src.CountingBloomFilter::with_size(64, 1)
  filter.insert("a")
  filter.insert("b")
  filter.insert("c")
  let batch = ["a", "missing", "c"]
  assert_false(filter.remove_all(batch))
  assert_false(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_false(filter.contains("c"))
  assert_eq(filter.count(), 1)
}

test "counting filter count_of distinguishes missing from false positive" {
  let filter = @src.CountingBloomFilter::with_size(4096, 4)
  filter.insert("present")
  filter.insert("present")
  assert_eq(filter.count_of("present"), 2)
  assert_eq(filter.count_of("missing"), 0)
  assert_true(filter.remove("present"))
  assert_eq(filter.count_of("present"), 1)
  assert_true(filter.remove("present"))
  assert_eq(filter.count_of("present"), 0)
  assert_false(filter.contains("present"))
}

test "counting filter remove_all reports success for missing in empty filter" {
  let filter = @src.CountingBloomFilter::with_size(64, 1)
  let batch = ["missing1", "missing2"]
  assert_false(filter.contains("missing1"))
  assert_false(filter.remove_all(batch))
}

test "counting filter saturation after removal still allows count_of queries" {
  let filter = @src.CountingBloomFilter::with_size(64, 1)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("wide")
  }
  assert_true(filter.count_of("wide") > 0)
  assert_eq(filter.count(), 1000)
  assert_true(filter.contains("wide"))
}

test "compact counting filter remove_all handles false positives gracefully" {
  let filter = @src.CompactCountingBloomFilter::with_size(64, 1)
  filter.insert("a")
  filter.insert("b")
  filter.insert("c")
  let batch = ["a", "missing", "c"]
  assert_false(filter.remove_all(batch))
  assert_true(filter.contains("b"))
}

test "compact counting filter saturates and drains correctly" {
  let filter = @src.CompactCountingBloomFilter::with_size(64, 1)
  for i = 0; i < 20; i = i + 1 {
    filter.insert("multi")
  }
  assert_eq(filter.count_of("multi"), 15)
  let after_sat = filter.count()
  assert_true(filter.remove("multi"))
  assert_eq(filter.count_of("multi"), 14)
  assert_eq(filter.count(), after_sat - 1)
}