///|
test "bloom filter contains_any handles present missing and empty batches" {
  let filter = @src.BloomFilter::with_size(1024, 4)
  let missing = ["missing", "absent"]
  let empty : Array[String] = []
  assert_false(filter.contains_any(missing))
  assert_false(filter.contains_any(empty))
  filter.insert("present")
  assert_true(filter.contains_any(["missing", "present"]))
}

///|
test "counting filter contains_any handles present missing and empty batches" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  let missing = ["missing", "absent"]
  let empty : Array[String] = []
  assert_false(filter.contains_any(missing))
  assert_false(filter.contains_any(empty))
  filter.insert("present")
  assert_true(filter.contains_any(["missing", "present"]))
}

///|
test "cuckoo filter contains_any handles present missing and empty batches" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  let missing = ["missing", "absent"]
  let empty : Array[String] = []
  assert_false(filter.contains_any(missing))
  assert_false(filter.contains_any(empty))
  assert_true(filter.insert("present"))
  assert_true(filter.contains_any(["missing", "present"]))
}

///|
test "concurrent filters expose contains_any" {
  let bloom = @src.ConcurrentBloomFilter::with_size(1024, 4)
  let counting = @src.ConcurrentCountingBloomFilter::with_size(1024, 4)
  let cuckoo = @src.ConcurrentCuckooFilter::with_size(64, 4)
  let empty : Array[String] = []
  assert_false(bloom.contains_any(empty))
  assert_false(counting.contains_any(empty))
  assert_false(cuckoo.contains_any(empty))
  bloom.insert("present")
  counting.insert("present")
  assert_true(cuckoo.insert("present"))
  assert_true(bloom.contains_any(["missing", "present"]))
  assert_true(counting.contains_any(["missing", "present"]))
  assert_true(cuckoo.contains_any(["missing", "present"]))
}
