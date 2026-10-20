///|
test "bloom filter batch inserts only absent keys" {
  let filter = @src.BloomFilter::with_size(8192, 4)
  let keys = ["a", "b", "a", "c", "b"]
  assert_eq(filter.insert_all_if_absent(keys), 3)
  assert_eq(filter.count(), 3)
  assert_true(filter.contains_all(["a", "b", "c"]))
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.count(), 3)
  let empty : Array[String] = []
  assert_eq(filter.insert_all_if_absent(empty), 0)
}

///|
test "counting filter batch inserts only absent keys" {
  let filter = @src.CountingBloomFilter::with_size(8192, 4)
  let keys = ["a", "b", "a", "c", "b"]
  assert_eq(filter.insert_all_if_absent(keys), 3)
  assert_eq(filter.count(), 3)
  assert_true(filter.contains_all(["a", "b", "c"]))
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("a"), 1)
}

///|
test "cuckoo filter batch inserts only absent keys" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  let keys = ["a", "b", "a", "c", "b"]
  assert_eq(filter.insert_all_if_absent(keys), 3)
  assert_eq(filter.count(), 3)
  assert_true(filter.contains_all(["a", "b", "c"]))
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.count(), 3)
  assert_eq(filter.count_of("a"), 1)
}

///|
test "concurrent wrappers expose batch conditional insertion" {
  let bloom = @src.ConcurrentBloomFilter::with_size(8192, 4)
  assert_eq(bloom.insert_all_if_absent(["a", "b", "a"]), 2)
  assert_eq(bloom.insert_all_if_absent(["a", "b"]), 0)
  assert_eq(bloom.count(), 2)
  let counting = @src.ConcurrentCountingBloomFilter::with_size(8192, 4)
  assert_eq(counting.insert_all_if_absent(["a", "b", "a"]), 2)
  assert_eq(counting.insert_all_if_absent(["a", "b"]), 0)
  assert_eq(counting.count(), 2)
  let cuckoo = @src.ConcurrentCuckooFilter::with_size(64, 4)
  assert_eq(cuckoo.insert_all_if_absent(["a", "b", "a"]), 2)
  assert_eq(cuckoo.insert_all_if_absent(["a", "b"]), 0)
  assert_eq(cuckoo.count(), 2)
}
