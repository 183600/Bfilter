///|
test "scalable bloom merge keeps a grown empty receiver's extra slices" {
  let receiver = ScalableBloomFilter::new(1, 0.01)
  for i = 0; i < 3; i = i + 1 {
    receiver.insert("grow-" + i.to_string())
  }
  assert_true(receiver.slice_count() > 1)
  let grown_slices = receiver.slice_count()
  // Simulate an already-grown receiver with no live keys. Bloom filters have no
  // removal API, so clear the backing slices directly in this whitebox setup;
  // the merge fast path must still retain the extra slice layout.
  for i = 0; i < receiver.slices.length(); i = i + 1 {
    receiver.slices[i].clear()
  }
  receiver.inserted = 0

  let source = ScalableBloomFilter::new(1, 0.01)
  source.insert("source")
  receiver.merge(source)
  assert_eq(receiver.slice_count(), grown_slices)
  assert_eq(receiver.count(), source.count())
  assert_true(receiver.contains("source"))

  // New insertions go into the retained newest slice and remain serializable.
  receiver.insert("after")
  assert_true(receiver.contains_all(["source", "after"]))
  let restored = ScalableBloomFilter::from_bytes(receiver.to_bytes())
  assert_eq(restored.slice_count(), receiver.slice_count())
  assert_eq(restored.count(), receiver.count())
  assert_true(restored.contains_all(["source", "after"]))
}

///|
test "scalable bloom merge appends source slices beyond a grown empty receiver" {
  let receiver = ScalableBloomFilter::new(1, 0.01)
  for i = 0; i < 2; i = i + 1 {
    receiver.insert("grow-" + i.to_string())
  }
  for i = 0; i < receiver.slices.length(); i = i + 1 {
    receiver.slices[i].clear()
  }
  receiver.inserted = 0
  let short_slices = receiver.slice_count()

  let source = ScalableBloomFilter::new(1, 0.01)
  for i = 0; i < 8; i = i + 1 {
    source.insert("source-" + i.to_string())
  }
  assert_true(source.slice_count() > short_slices)
  let source_bytes = source.to_bytes()
  receiver.merge(source)
  assert_eq(receiver.slice_count(), source.slice_count())
  assert_eq(receiver.count(), source.count())
  for i = 0; i < 8; i = i + 1 {
    assert_true(receiver.contains("source-" + i.to_string()))
  }
  assert_eq(source.to_bytes(), source_bytes)
  let restored = ScalableBloomFilter::from_bytes(receiver.to_bytes())
  assert_eq(restored.slice_count(), source.slice_count())
  for i = 0; i < 8; i = i + 1 {
    assert_true(restored.contains("source-" + i.to_string()))
  }
}

///|
test "scalable bloom merge keeps slices of a multi-slice intersection result" {
  let left = ScalableBloomFilter::new(2, 0.01)
  let right = ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 12; i = i + 1 {
    left.insert("left-" + i.to_string())
    right.insert("right-" + i.to_string())
  }
  assert_true(left.slice_count() > 1)
  assert_eq(left.slice_count(), right.slice_count())
  let common = left.intersection(right)
  assert_eq(common.count(), left.count().min(right.count()))
  let common_slices = common.slice_count()

  let source = ScalableBloomFilter::new(2, 0.01)
  source.insert("source")
  let source_count = source.count()
  common.merge(source)
  assert_eq(common.slice_count(), common_slices)
  assert_eq(common.count(), left.count().min(right.count()) + source_count)
  assert_true(common.contains("source"))
  let restored = ScalableBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.slice_count(), common.slice_count())
  assert_eq(restored.count(), common.count())
  assert_true(restored.contains("source"))
}
