///|
test "scalable bloom intersection keeps keys shared by corresponding slices" {
  let left = @src.ScalableBloomFilter::new(8, 0.000001)
  let right = @src.ScalableBloomFilter::new(8, 0.000001)
  for i = 0; i < 16; i = i + 1 {
    let key = "shared-" + i.to_string()
    left.insert(key)
    right.insert(key)
  }
  for i = 0; i < 16; i = i + 1 {
    left.insert("left-" + i.to_string())
    right.insert("right-" + i.to_string())
  }
  assert_eq(left.slice_count(), right.slice_count())
  let common = left.intersection(right)
  for i = 0; i < 16; i = i + 1 {
    assert_true(common.contains("shared-" + i.to_string()))
  }
  assert_false(common.contains("left-0"))
  assert_false(common.contains("right-0"))
  assert_true(common.count() <= left.count().min(right.count()))
  let restored = @src.ScalableBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.count(), common.count())
  assert_true(restored.contains("shared-0"))
  assert_eq(left.contains("left-0"), true)
  assert_eq(right.contains("right-0"), true)
}

///|
test "scalable bloom intersection omits slices without a counterpart" {
  let short = @src.ScalableBloomFilter::new(4, 0.000001)
  let long = @src.ScalableBloomFilter::new(4, 0.000001)
  for i = 0; i < 4; i = i + 1 {
    short.insert("shared-" + i.to_string())
    long.insert("shared-" + i.to_string())
  }
  for i = 0; i < 20; i = i + 1 {
    long.insert("long-" + i.to_string())
  }
  assert_true(long.slice_count() > short.slice_count())
  let common = long.intersection(short)
  assert_eq(common.slice_count(), short.slice_count())
  for i = 0; i < 4; i = i + 1 {
    assert_true(common.contains("shared-" + i.to_string()))
  }
  assert_false(common.contains("long-0"))
  let restored = @src.ScalableBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.slice_count(), common.slice_count())
  assert_true(restored.contains("shared-0"))
}

///|
test "scalable counting intersection keeps shared keys from different slices" {
  let left = @src.ScalableCountingBloomFilter::new(4, 0.000001)
  let right = @src.ScalableCountingBloomFilter::new(4, 0.000001)
  left.insert("shared")
  for i = 0; i < 8; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 30; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  right.insert("shared")
  right.insert("shared")
  assert_true(left.slice_count() > 1)
  assert_true(right.slice_count() > left.slice_count())
  let common = left.intersection(right)
  assert_eq(common.slice_count(), left.slice_count().min(right.slice_count()))
  assert_eq(common.count_of("shared"), 1)
  assert_true(common.contains("shared"))
  assert_eq(common.count_of("left-0"), 0)
  assert_eq(common.count_of("right-0"), 0)
  assert_false(common.contains("left-0"))
  assert_false(common.contains("right-0"))
  assert_true(common.count() <= left.count().min(right.count()))
  let restored = @src.ScalableCountingBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.count(), common.count())
  assert_eq(restored.count_of("shared"), 1)
  assert_true(restored.contains("shared"))
  assert_true(common.remove("shared"))
  assert_eq(common.count_of("shared"), 0)
  assert_false(common.contains("shared"))
  assert_false(common.remove("shared"))
  let reversed = right.intersection(left)
  assert_eq(reversed.count_of("shared"), 1)
  assert_true(reversed.contains("shared"))
}

///|
test "concurrent scalable wrappers expose atomic intersection" {
  let bloom_left = @src.ConcurrentScalableBloomFilter::new(8, 0.000001)
  let bloom_right = @src.ScalableBloomFilter::new(8, 0.000001)
  bloom_left.insert("shared")
  bloom_right.insert("shared")
  bloom_left.insert("left-only")
  bloom_right.insert("right-only")
  let bloom_common = bloom_left.intersection(bloom_right)
  assert_true(bloom_common.contains("shared"))
  assert_false(bloom_common.contains("left-only"))
  assert_false(bloom_common.contains("right-only"))

  let counting_left = @src.ConcurrentScalableCountingBloomFilter::new(
    4, 0.000001,
  )
  let counting_right = @src.ScalableCountingBloomFilter::new(4, 0.000001)
  counting_left.insert("shared")
  counting_right.insert("shared")
  counting_right.insert("shared")
  counting_left.insert("left-only")
  counting_right.insert("right-only")
  let counting_common = counting_left.intersection(counting_right)
  assert_eq(counting_common.count_of("shared"), 1)
  assert_true(counting_common.contains("shared"))
  assert_eq(counting_common.count_of("left-only"), 0)
  assert_eq(counting_common.count_of("right-only"), 0)
}
