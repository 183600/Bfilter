///|
test "docs: scalable bloom intersection caveat, same key in different slices" {
  let left = @src.ScalableBloomFilter::new(4, 0.000001)
  let right = @src.ScalableBloomFilter::new(4, 0.000001)
  left.insert("shared")
  for i = 0; i < 8; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 30; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  right.insert("shared")
  assert_true(left.slice_count() > 1)
  assert_true(right.slice_count() > left.slice_count())
  let common = left.intersection(right)
  assert_false(common.contains("shared"))
  assert_true(left.contains("shared"))
  assert_true(right.contains("shared"))
}

///|
test "docs: readme blocked bloom filter block layout" {
  let filter = @src.BlockedBloomFilter::new(10_000, 0.01)
  filter.insert_all(["alpha", "beta"])
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains_all(["alpha", "beta"]))
  assert_eq(filter.bit_count() % 512, 0)
  assert_eq(filter.block_count(), filter.bit_count() / 512)
}

///|
test "docs: readme scalable counting bloom filter tracks multiplicity" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("session")
  filter.insert("session")
  assert_eq(filter.count_of("session"), 2)
  assert_true(filter.remove("session"))
  assert_eq(filter.count_of("session"), 1)
}

///|
test "docs: guide scalable counting bloom filter growth and tracking" {
  let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  for i = 0; i < 40; i = i + 1 {
    filter.insert("key-" + i.to_string())
  }
  filter.insert("key-0")
  assert_true(filter.slice_count() > 1)
  assert_eq(filter.count_of("key-0"), 2)
  assert_true(filter.remove("key-0"))
  assert_eq(filter.count_of("key-0"), 1)
  assert_eq(filter.tracked_key_count(), 40)
}

///|
test "docs: guide scalable bloom filter target rate budget" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 1000)
  assert_true(filter.target_false_positive_rate() == 0.01)
  assert_true(filter.false_positive_rate() < 0.01)
}

///|
test "docs: readme serialization round trip scalable" {
  let original = @src.ScalableBloomFilter::new(1_000, 0.01)
  original.insert("saved")
  let restored = @src.ScalableBloomFilter::from_bytes(original.to_bytes())
  assert_true(restored.contains("saved"))
}

///|
test "docs: readme bloom filter false positive budget" {
  let filter = @src.BloomFilter::new(10_000, 0.01)
  filter.insert("alpha")
  filter.insert_all(["beta", "gamma"])
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains_all(["beta", "gamma"]))
  assert_false(filter.contains("not-inserted"))
  assert_true(filter.false_positive_rate() < 0.02)
}

///|
test "docs: guide bloom filter sized workload meets target rate" {
  let filter = @src.BloomFilter::new(10_000, 0.001)
  for i = 0; i < 10_000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.contains(123))
  assert_true(filter.false_positive_rate() < 0.01)
}

///|
test "docs: readme compact counting memory ratio" {
  let compact = @src.CompactCountingBloomFilter::new(1_000, 0.01)
  let regular = @src.CountingBloomFilter::new(1_000, 0.01)
  assert_eq(regular.memory_bytes(), compact.memory_bytes() * 4L)
  compact.insert("task")
  compact.insert("task")
  assert_eq(compact.count_of("task"), 2)
  assert_true(compact.remove("task"))
  assert_eq(compact.count_of("task"), 1)
}
