///|
test "counting bloom remove leaves no residue after dense churn" {
  let filter = @src.CountingBloomFilter::with_size(64, 12)
  let keys : Array[String] = Array::makei(200, i => "churn-" + i.to_string())
  for round = 0; round < 5; round = round + 1 {
    for key in keys {
      filter.insert(key)
    }
  }
  for key in keys {
    for i = 0; i < 5; i = i + 1 {
      assert_true(filter.remove(key))
    }
  }
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "compact counting remove leaves no residue after dense churn" {
  let filter = @src.CompactCountingBloomFilter::with_size(512, 6)
  let keys : Array[String] = Array::makei(200, i => "churn-" + i.to_string())
  for key in keys {
    filter.insert(key)
  }
  for key in keys {
    assert_true(filter.remove(key))
  }
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "counting bloom removes saturated duplicate positions" {
  let filter = @src.CountingBloomFilter::with_size(16, 20)
  for i = 0; i < 40000; i = i + 1 {
    filter.insert(0)
  }
  for i = 0; i < 40000; i = i + 1 {
    ignore(filter.remove(0))
  }
  assert_false(filter.contains(0))
  assert_eq(filter.count_of(0), 0)
}

///|
test "compact counting removes saturated duplicate positions" {
  let filter = @src.CompactCountingBloomFilter::with_size(16, 20)
  for i = 0; i < 40; i = i + 1 {
    filter.insert(0)
  }
  for i = 0; i < 40; i = i + 1 {
    ignore(filter.remove(0))
  }
  assert_false(filter.contains(0))
  assert_eq(filter.count_of(0), 0)
}

///|
test "compact counting saturated shared positions can drop inserted keys" {
  // With sixteen slots and 128 hashes every key hits each slot eight times, so
  // both keys saturate the same lanes and the second insert is skipped.
  let filter = @src.CompactCountingBloomFilter::with_size(16, 128)
  filter.insert("alpha")
  filter.insert("beta")
  assert_true(filter.contains("beta"))
  assert_true(filter.remove("alpha"))
  assert_false(filter.contains("beta"))
  assert_false(filter.remove("beta"))
}

///|
test "compact counting removes keys whose duplicate positions exceed the counter width" {
  let filter = @src.CompactCountingBloomFilter::with_size(16, 300)
  filter.insert(0)
  assert_true(filter.contains(0))
  assert_eq(filter.count_of(0), @src.CompactCountingBloomFilter::counter_max())
  assert_true(filter.remove(0))
  assert_false(filter.contains(0))
  assert_eq(filter.count_of(0), 0)
  assert_eq(filter.count(), 0)
}

///|
test "counting bloom removes keys with more duplicate positions than counter width" {
  let filter = @src.CountingBloomFilter::with_size(16, 70000)
  filter.insert(0)
  assert_true(filter.contains(0))
  assert_true(filter.remove(0))
  assert_false(filter.contains(0))
  assert_eq(filter.count_of(0), 0)
  assert_eq(filter.count(), 0)
}

///|
test "counting bloom conditional insert handles duplicate positions once" {
  let filter = @src.CountingBloomFilter::with_size(16, 70000)
  assert_true(filter.insert_if_absent(0))
  assert_false(filter.insert_if_absent(0))
  assert_eq(filter.count(), 1)
  assert_true(filter.remove(0))
  assert_false(filter.contains(0))
  assert_true(filter.insert_if_absent(0))
  assert_eq(filter.count(), 1)
}

///|
test "compact counting conditional insert handles duplicate positions once" {
  let filter = @src.CompactCountingBloomFilter::with_size(16, 300)
  assert_true(filter.insert_if_absent(0))
  assert_false(filter.insert_if_absent(0))
  assert_eq(filter.count(), 1)
  assert_true(filter.remove(0))
  assert_false(filter.contains(0))
  assert_true(filter.insert_if_absent(0))
  assert_eq(filter.count(), 1)
}

///|
test "counting filters report insertions when probes repeat positions" {
  let counting = @src.CountingBloomFilter::with_size(16, 128)
  counting.insert("repeat")
  assert_eq(counting.count_of("repeat"), 1)
  counting.insert("repeat")
  assert_eq(counting.count_of("repeat"), 2)
  assert_true(counting.remove("repeat"))
  assert_eq(counting.count_of("repeat"), 1)
  assert_true(counting.remove("repeat"))
  assert_eq(counting.count_of("repeat"), 0)
  assert_false(counting.contains("repeat"))

  let uneven = @src.CountingBloomFilter::with_size(16, 17)
  for i = 0; i < 3; i = i + 1 {
    uneven.insert("uneven")
  }
  assert_eq(uneven.count_of("uneven"), 3)

  let compact = @src.CompactCountingBloomFilter::with_size(16, 128)
  compact.insert("repeat")
  assert_eq(compact.count_of("repeat"), 1)
  assert_true(compact.remove("repeat"))
  assert_eq(compact.count_of("repeat"), 0)
  assert_false(compact.contains("repeat"))

  let compact_uneven = @src.CompactCountingBloomFilter::with_size(16, 17)
  for i = 0; i < 3; i = i + 1 {
    compact_uneven.insert("uneven")
  }
  assert_eq(compact_uneven.count_of("uneven"), 3)
}
