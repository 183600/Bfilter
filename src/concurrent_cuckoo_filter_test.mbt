///|
test "concurrent cuckoo filter insert remove and clear" {
  let filter = @src.ConcurrentCuckooFilter::new(200)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_true(filter.insert("alpha"))
  assert_true(filter.insert(42))
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("alpha"))
  assert_false(filter.contains("alpha"))
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 1)
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_false(filter.contains(42))
}

///|
test "concurrent cuckoo filter tracks duplicate insertions" {
  let filter = @src.ConcurrentCuckooFilter::with_size(16, 4)
  assert_true(filter.insert("same"))
  assert_true(filter.insert("same"))
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("same"))
  assert_true(filter.contains("same"))
  assert_true(filter.remove("same"))
  assert_false(filter.contains("same"))
  assert_false(filter.remove("same"))
}

///|
test "concurrent cuckoo filter batch operations share one lock" {
  let keys = ["a", "b", "c", "d"]
  let filter = @src.ConcurrentCuckooFilter::with_size(16, 4)
  assert_true(filter.insert_all(keys))
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  assert_true(filter.remove_all(keys))
  assert_true(filter.is_empty())
  let empty : Array[String] = []
  assert_true(filter.insert_all(empty))
  assert_true(filter.remove_all(empty))
  assert_true(filter.contains_all(empty))
  assert_eq(filter.count(), 0)
}

///|
test "concurrent cuckoo filter reports layout" {
  let filter = @src.ConcurrentCuckooFilter::with_size(3, 2)
  assert_eq(filter.bucket_count(), 4)
  assert_eq(filter.bucket_size(), 2)
}

///|
test "concurrent cuckoo filter reports failed inserts" {
  let filter = @src.ConcurrentCuckooFilter::with_size(1, 1)
  assert_true(filter.insert("alpha"))
  assert_false(filter.insert("beta"))
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("alpha"))
}

///|
test "concurrent cuckoo filter batch conditional inserts track additions" {
  let filter = @src.ConcurrentCuckooFilter::with_size(256, 4)
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
test "panic concurrent cuckoo filter rejects invalid configuration" {
  @src.ConcurrentCuckooFilter::new(0) |> ignore
}

///|
test "concurrent cuckoo filter serialization preserves eviction state" {
  let filter = @src.ConcurrentCuckooFilter::with_size(8, 2)
  let keys = [559187, 354192, 64393, 338638, 263727, 750268, 509445]
  for key in keys {
    assert_true(filter.insert(key))
  }
  let restored = @src.ConcurrentCuckooFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_true(restored.contains(559187))
  // The restored filter should accept new inserts with the same behavior
  assert_true(restored.insert(228423))
  assert_true(restored.contains(228423))
  assert_eq(restored.count(), filter.count() + 1)
}

///|
test "concurrent cuckoo filter survives interleaved workload" {
  let filter = @src.ConcurrentCuckooFilter::new(1000)
  for i = 0; i < 500; i = i + 1 {
    assert_true(filter.insert("key-" + i.to_string()))
    if i % 3 == 0 {
      assert_true(filter.contains("key-" + i.to_string()))
    }
    if i % 7 == 0 {
      assert_true(filter.remove("key-" + i.to_string()))
    }
  }
  for i = 0; i < 500; i = i + 1 {
    if i % 7 != 0 {
      assert_true(filter.contains("key-" + i.to_string()))
    }
  }
  assert_eq(filter.count(), 428)
}
