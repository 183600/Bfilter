///|
test "scalable bloom set operations preserve membership with clamped slice rates" {
  let rate = @double.min_positive / 1.0e15
  let left = @src.ScalableBloomFilter::new(1, rate)
  let right = @src.ScalableBloomFilter::new(1, rate)
  let keys : Array[String] = Array::makei(8, i => "clamped-" + i.to_string())
  for key in keys {
    left.insert(key)
    right.insert(key)
  }
  assert_eq(left.slice_count(), 4)
  let combined = left.union(right)
  assert_eq(combined.slice_count(), 4)
  assert_true(combined.contains_all(keys))
  let common = left.intersection(right)
  assert_true(common.contains_all(keys))
  let restored = @src.ScalableBloomFilter::from_bytes(combined.to_bytes())
  assert_true(restored.contains_all(keys))
  assert_eq(restored.slice_count(), combined.slice_count())
}

///|
test "scalable counting set operations preserve tracked keys with clamped slice rates" {
  let rate = @double.min_positive / 1.0e15
  let left = @src.ScalableCountingBloomFilter::new(1, rate)
  let right = @src.ScalableCountingBloomFilter::new(1, rate)
  let keys : Array[String] = Array::makei(8, i => "clamped-" + i.to_string())
  for key in keys {
    left.insert(key)
    right.insert(key)
  }
  left.insert("clamped-0")
  right.insert("clamped-0")
  right.insert("clamped-0")
  assert_eq(left.slice_count(), 4)
  let combined = left.union(right)
  assert_eq(combined.count_of("clamped-0"), 3)
  for key in keys {
    assert_true(combined.contains(key))
  }
  let common = left.intersection(right)
  assert_eq(common.count_of("clamped-0"), 2)
  for key in keys {
    assert_true(common.contains(key))
  }
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_eq(restored.count_of("clamped-0"), 3)
  for key in keys {
    assert_true(restored.contains(key))
  }
}
