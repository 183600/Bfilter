///|
test "scalable bloom filter merge reports keys from both inputs" {
  let left = @src.ScalableBloomFilter::new(4, 0.01)
  let right = @src.ScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 12; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 6; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  left.merge(right)
  assert_eq(left.count(), 18)
  for i = 0; i < 12; i = i + 1 {
    assert_true(left.contains("left-" + i.to_string()))
  }
  for i = 0; i < 6; i = i + 1 {
    assert_true(left.contains("right-" + i.to_string()))
  }
  assert_false(left.contains("definitely-absent-from-both-filters"))
  assert_eq(right.count(), 6)
}

///|
test "scalable bloom filter merge appends slices only the other side holds" {
  let small = @src.ScalableBloomFilter::new(32, 0.01)
  let large = @src.ScalableBloomFilter::new(32, 0.01)
  small.insert("early")
  for i = 0; i < 70; i = i + 1 {
    large.insert(i)
  }
  assert_true(large.slice_count() > small.slice_count())
  let slices_before = small.slice_count()
  small.merge(large)
  assert_eq(small.slice_count(), large.slice_count())
  assert_true(small.slice_count() > slices_before)
  assert_true(small.contains("early"))
  for i = 0; i < 70; i = i + 1 {
    assert_true(small.contains(i))
  }
  small.insert("after-merge")
  assert_true(small.contains("after-merge"))
}

///|
test "scalable bloom filter union leaves both inputs unchanged" {
  let left = @src.ScalableBloomFilter::new(4, 0.01)
  let right = @src.ScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 10; i = i + 1 {
    left.insert("shared-" + (i % 5).to_string())
    right.insert("shared-" + (i % 5).to_string())
  }
  right.insert("only-right")
  let combined = left.union(right)
  assert_eq(combined.count(), left.count() + right.count())
  for i = 0; i < 5; i = i + 1 {
    assert_true(combined.contains("shared-" + i.to_string()))
  }
  assert_true(combined.contains("only-right"))
  assert_false(left.contains("only-right"))
  assert_eq(left.count(), 10)
  assert_eq(right.count(), 11)
}

///|
test "scalable bloom filter is_subset_of follows slice layouts" {
  let base = @src.ScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 15; i = i + 1 {
    base.insert(i)
  }
  let superset = base.copy()
  superset.insert("extra")
  assert_true(base.is_subset_of(superset))
  assert_true(superset.is_subset_of(superset))
  assert_true(base.is_subset_of(base))
  assert_false(superset.is_subset_of(base))
}

///|
test "scalable bloom filter is_subset_of rejects non-empty extra slices" {
  let long = @src.ScalableBloomFilter::new(2, 0.01)
  let short = @src.ScalableBloomFilter::new(2, 0.01)
  short.insert("kept")
  for i = 0; i < 20; i = i + 1 {
    long.insert(i)
  }
  assert_true(long.slice_count() > short.slice_count())
  assert_false(long.is_subset_of(short))
  long.clear()
  assert_true(long.is_subset_of(short))
}

///|
test "scalable bloom filter merged filters keep working after growth" {
  let left = @src.ScalableBloomFilter::new(2, 0.01)
  let right = @src.ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 8; i = i + 1 {
    left.insert("l" + i.to_string())
    right.insert("r" + i.to_string())
  }
  left.merge(right)
  let slices_before = left.slice_count()
  for i = 0; i < 20; i = i + 1 {
    left.insert("grow-" + i.to_string())
  }
  assert_true(left.slice_count() > slices_before)
  for i = 0; i < 8; i = i + 1 {
    assert_true(left.contains("l" + i.to_string()))
    assert_true(left.contains("r" + i.to_string()))
  }
  for i = 0; i < 20; i = i + 1 {
    assert_true(left.contains("grow-" + i.to_string()))
  }
}

///|
test "scalable bloom filter merged filters survive serialization" {
  let left = @src.ScalableBloomFilter::new(4, 0.01)
  let right = @src.ScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 14; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 9; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  left.merge(right)
  let restored = @src.ScalableBloomFilter::from_bytes(left.to_bytes())
  assert_eq(restored.count(), left.count())
  assert_eq(restored.slice_count(), left.slice_count())
  assert_eq(restored.bit_count(), left.bit_count())
  for i = 0; i < 14; i = i + 1 {
    assert_true(restored.contains("left-" + i.to_string()))
  }
  for i = 0; i < 9; i = i + 1 {
    assert_true(restored.contains("right-" + i.to_string()))
  }
}

///|
test "panic scalable bloom filter merge rejects different policies" {
  let left = @src.ScalableBloomFilter::new(4, 0.01)
  let right_capacity = @src.ScalableBloomFilter::new(8, 0.01)
  left.merge(right_capacity)
  let right_rate = @src.ScalableBloomFilter::new(4, 0.001)
  left.merge(right_rate)
}

///|
test "panic scalable bloom filter union rejects different policies" {
  let left = @src.ScalableBloomFilter::new(4, 0.01)
  let right = @src.ScalableBloomFilter::new(4, 0.02)
  left.union(right) |> ignore
}

///|
test "panic scalable bloom filter is_subset_of rejects different policies" {
  let left = @src.ScalableBloomFilter::new(4, 0.01)
  let right = @src.ScalableBloomFilter::new(8, 0.01)
  left.is_subset_of(right) |> ignore
}

///|
test "concurrent scalable bloom filter supports set operations" {
  let left = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  let right = @src.ScalableBloomFilter::new(4, 0.01)
  for i = 0; i < 10; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 6; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  let snapshot = left.snapshot()
  assert_true(snapshot.is_subset_of(left.union(right)))
  left.merge(right)
  assert_eq(left.count(), 16)
  for i = 0; i < 10; i = i + 1 {
    assert_true(left.contains("left-" + i.to_string()))
  }
  for i = 0; i < 6; i = i + 1 {
    assert_true(left.contains("right-" + i.to_string()))
  }
  assert_true(left.is_subset_of(left.snapshot()))
}
