///|
test "counting filter reports multiplicity of duplicate insertions" {
  let filter = @src.CountingBloomFilter::with_size(8192, 4)
  assert_eq(filter.count_of("value"), 0)
  filter.insert("value")
  assert_eq(filter.count_of("value"), 1)
  filter.insert("value")
  filter.insert("value")
  assert_eq(filter.count_of("value"), 3)
  assert_true(filter.remove("value"))
  assert_eq(filter.count_of("value"), 2)
  assert_true(filter.remove("value"))
  assert_true(filter.remove("value"))
  assert_eq(filter.count_of("value"), 0)
  assert_false(filter.contains("value"))
}

///|
test "counting filter multiplicity follows clear" {
  let filter = @src.CountingBloomFilter::with_size(1024, 3)
  filter.insert("value")
  filter.insert("value")
  assert_eq(filter.count_of("value"), 2)
  filter.clear()
  assert_eq(filter.count_of("value"), 0)
}

///|
test "cuckoo filter reports multiplicity of duplicate insertions" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  assert_eq(filter.count_of("value"), 0)
  assert_true(filter.insert("value"))
  assert_eq(filter.count_of("value"), 1)
  assert_true(filter.insert("value"))
  assert_true(filter.insert("value"))
  assert_eq(filter.count_of("value"), 3)
  assert_true(filter.remove("value"))
  assert_eq(filter.count_of("value"), 2)
  assert_true(filter.remove("value"))
  assert_true(filter.remove("value"))
  assert_eq(filter.count_of("value"), 0)
  assert_false(filter.contains("value"))
}

///|
test "cuckoo filter multiplicity is zero after clear" {
  let filter = @src.CuckooFilter::with_size(16, 2)
  assert_true(filter.insert("value"))
  assert_eq(filter.count_of("value"), 1)
  filter.clear()
  assert_eq(filter.count_of("value"), 0)
}

///|
test "concurrent wrappers expose multiplicities" {
  let counting = @src.ConcurrentCountingBloomFilter::with_size(4096, 4)
  counting.insert("value")
  counting.insert("value")
  assert_eq(counting.count_of("value"), 2)
  assert_true(counting.remove("value"))
  assert_eq(counting.count_of("value"), 1)
  counting.clear()
  assert_eq(counting.count_of("value"), 0)
  let cuckoo = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_true(cuckoo.insert("value"))
  assert_true(cuckoo.insert("value"))
  assert_eq(cuckoo.count_of("value"), 2)
  assert_true(cuckoo.remove("value"))
  assert_eq(cuckoo.count_of("value"), 1)
  cuckoo.clear()
  assert_eq(cuckoo.count_of("value"), 0)
}
