///|
test "scalable bloom filter insert_if_absent on empty filter" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_true(filter.contains("key"))
  assert_eq(filter.count(), 1)
}

///|
test "scalable bloom filter insert_if_absent prevents duplicate insertions" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  filter.insert("key")
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "scalable bloom filter insert_all_if_absent" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  let keys = ["a", "b", "c", "d", "e"]
  let added = filter.insert_all_if_absent(keys)
  assert_eq(added, 5)
  assert_eq(filter.count(), 5)
  // Second call should add nothing
  let added2 = filter.insert_all_if_absent(keys)
  assert_eq(added2, 0)
  assert_eq(filter.count(), 5)
  // Mixed existing and new keys
  let mixed = ["c", "f", "g"]
  let added3 = filter.insert_all_if_absent(mixed)
  assert_eq(added3, 2)
  assert_eq(filter.count(), 7)
}

///|
test "scalable counting filter insert_if_absent on empty filter" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_true(filter.contains("key"))
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of("key"), 1)
}

///|
test "scalable counting filter insert_if_absent prevents duplicate insertions" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("key")
  filter.insert("key")
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 2)
  assert_eq(filter.count_of("key"), 2)
}

///|
test "scalable counting filter insert_if_absent across slice growth" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  // Insert 40 keys - some might be suppressed by false positives
  let mut inserted_count = 0
  for i = 0; i < 40; i = i + 1 {
    let result = filter.insert_if_absent("key-" + i.to_string())
    if result {
      inserted_count = inserted_count + 1
    }
  }
  assert_true(filter.slice_count() > 1)
  // Check that insert_if_absent returns false for keys that are confirmed present
  for i = 0; i < 40; i = i + 1 {
    let contains = filter.contains("key-" + i.to_string())
    let result = filter.insert_if_absent("key-" + i.to_string())
    // If contains is true, insert_if_absent should return false
    if contains && result {
      abort("key-" + i.to_string() + ": contains=true but insert_if_absent=true")
    }
    if !contains && !result {
      abort("key-" + i.to_string() + ": contains=false but insert_if_absent=false")
    }
    if contains {
      break
    }
  }
  assert_true(filter.count() > 0)
  // The count should equal the number of successful insertions
  assert_eq(filter.count(), inserted_count)
  // For keys that were actually inserted (tracked), count_of should be 1
  // Note: contains can return true for false positives, but count_of only tracks actual insertions
  for i = 0; i < 40; i = i + 1 {
    let count_of = filter.count_of("key-" + i.to_string())
    if count_of > 0 {
      assert_eq(count_of, 1)
    }
  }
}

///|
test "scalable counting filter insert_all_if_absent" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  let keys = ["a", "b", "c", "d", "e"]
  let added = filter.insert_all_if_absent(keys)
  assert_eq(added, 5)
  assert_eq(filter.count(), 5)
  // Second call should add nothing
  let added2 = filter.insert_all_if_absent(keys)
  assert_eq(added2, 0)
  assert_eq(filter.count(), 5)
  // Mixed existing and new keys
  let mixed = ["c", "f", "g"]
  let added3 = filter.insert_all_if_absent(mixed)
  assert_eq(added3, 2)
  assert_eq(filter.count(), 7)
  for key in keys {
    assert_eq(filter.count_of(key), 1)
  }
  assert_eq(filter.count_of("f"), 1)
  assert_eq(filter.count_of("g"), 1)
}

///|
test "concurrent scalable bloom filter insert_if_absent" {
  let filter = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_true(filter.contains("key"))
  assert_eq(filter.count(), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
}

///|
test "concurrent scalable bloom filter insert_all_if_absent" {
  let filter = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  let keys = ["a", "b", "c", "d", "e"]
  let added = filter.insert_all_if_absent(keys)
  assert_eq(added, 5)
  assert_eq(filter.count(), 5)
  let added2 = filter.insert_all_if_absent(keys)
  assert_eq(added2, 0)
  assert_eq(filter.count(), 5)
}

///|
test "concurrent scalable counting filter insert_if_absent" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  assert_true(filter.insert_if_absent("key"))
  assert_true(filter.contains("key"))
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of("key"), 1)
  assert_false(filter.insert_if_absent("key"))
  assert_eq(filter.count(), 1)
  assert_eq(filter.count_of("key"), 1)
}

///|
test "concurrent scalable counting filter insert_all_if_absent" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  let keys = ["a", "b", "c", "d", "e"]
  let added = filter.insert_all_if_absent(keys)
  assert_eq(added, 5)
  assert_eq(filter.count(), 5)
  let added2 = filter.insert_all_if_absent(keys)
  assert_eq(added2, 0)
  assert_eq(filter.count(), 5)
}

///|
test "concurrent scalable counting filter count_of" {
  let filter = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("key")
  filter.insert("key")
  assert_eq(filter.count_of("key"), 2)
  assert_true(filter.remove("key"))
  assert_eq(filter.count_of("key"), 1)
  assert_true(filter.remove("key"))
  assert_eq(filter.count_of("key"), 0)
  assert_false(filter.contains("key"))
  assert_eq(filter.count_of("missing"), 0)
}

///|
test "concurrent scalable bloom filter is_disjoint_from" {
  let left = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  let right = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  left.insert("left")
  right.insert("right")
  assert_true(left.is_disjoint_from(right.snapshot()))
  assert_true(right.is_disjoint_from(left.snapshot()))
  left.merge(right.snapshot())
  assert_false(left.is_disjoint_from(right.snapshot()))
}

///|
test "concurrent scalable counting filter is_disjoint_from" {
  let left = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  let right = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  left.insert("left")
  right.insert("right")
  assert_true(left.is_disjoint_from(right.snapshot()))
  assert_true(right.is_disjoint_from(left.snapshot()))
  left.merge(right.snapshot())
  assert_false(left.is_disjoint_from(right.snapshot()))
}

///|
test "scalable bloom filter insert_if_absent with false positives" {
  let filter = @src.ScalableBloomFilter::new(4, 0.5)
  // Insert many keys to increase false positive rate
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  // A false positive might suppress insertion, but we just verify it doesn't panic
  filter.insert_if_absent("maybe-false-positive") |> ignore
  filter.insert_all_if_absent(["maybe-fp-1", "maybe-fp-2"]) |> ignore
}

///|
test "scalable counting filter insert_if_absent with false positives" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.5)
  // Insert many keys to increase false positive rate
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  // A false positive might suppress insertion, but we just verify it doesn't panic
  filter.insert_if_absent("maybe-false-positive") |> ignore
  filter.insert_all_if_absent(["maybe-fp-1", "maybe-fp-2"]) |> ignore
}
///|
test "scalable bloom filter insert_if_absent across slice growth" {
  let filter = @src.ScalableBloomFilter::new(4, 0.01)
  // Insert 40 keys - some might be suppressed by false positives
  let mut inserted_count = 0
  for i = 0; i < 40; i = i + 1 {
    let result = filter.insert_if_absent("key-" + i.to_string())
    if result {
      inserted_count = inserted_count + 1
    }
  }
  assert_true(filter.slice_count() > 1)
  // Check that insert_if_absent returns false for keys that are confirmed present
  for i = 0; i < 40; i = i + 1 {
    let contains = filter.contains("key-" + i.to_string())
    let result = filter.insert_if_absent("key-" + i.to_string())
    // If contains is true, insert_if_absent should return false
    if contains && result {
      abort("key-" + i.to_string() + ": contains=true but insert_if_absent=true")
    }
    if !contains && !result {
      abort("key-" + i.to_string() + ": contains=false but insert_if_absent=false")
    }
    if contains {
      break
    }
  }
  assert_true(filter.count() > 0)
  // The count should equal the number of successful insertions
  assert_eq(filter.count(), inserted_count)
}
