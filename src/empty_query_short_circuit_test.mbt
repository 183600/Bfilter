///|
test "empty cuckoo filter answers queries and removals without state changes" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  let before = filter.to_bytes()
  assert_false(filter.contains("absent"))
  assert_eq(filter.count_of("absent"), 0)
  assert_false(filter.remove("absent"))
  assert_eq(filter.to_bytes(), before)

  assert_true(filter.insert("present"))
  assert_true(filter.remove("present"))
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("present"))
  assert_eq(filter.count_of("present"), 0)
  assert_false(filter.remove("present"))
}

///|
test "full cuckoo filter rejects conditional insertion without changing state" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert("only"))
  assert_true(filter.is_full())
  let before = filter.to_bytes()
  let count = filter.count()
  assert_false(filter.insert_if_absent("another"))
  assert_eq(filter.count(), count)
  assert_eq(filter.to_bytes(), before)
  assert_true(filter.contains("only"))
}

///|
test "cleared scalable filters answer empty queries" {
  let bloom = @src.ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    bloom.insert(i)
  }
  assert_true(bloom.slice_count() > 1)
  bloom.clear()
  assert_eq(bloom.count(), 0)
  assert_eq(bloom.slice_count(), 1)
  assert_false(bloom.contains("absent"))
  assert_false(bloom.contains_all(["absent", "missing"]))
  assert_false(bloom.contains_any(["absent", "missing"]))

  let counting = @src.ScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    counting.insert(i)
  }
  assert_true(counting.slice_count() > 1)
  counting.clear()
  assert_eq(counting.count(), 0)
  assert_eq(counting.slice_count(), 1)
  assert_eq(counting.tracked_key_count(), 0)
  assert_false(counting.contains("absent"))
  assert_eq(counting.count_of("absent"), 0)
  assert_false(counting.remove("absent"))
}
