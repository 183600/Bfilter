///|
test "scalable bloom subset rejects non-empty slices beyond the other filter" {
  let short = ScalableBloomFilter::new(2, 0.01)
  short.insert("kept-a")
  short.insert("kept-b")
  let long = short.copy()
  for i = 0; i < 12; i = i + 1 {
    long.insert("extra-" + i.to_string())
  }
  assert_true(long.slice_count() > short.slice_count())
  assert_true(short.is_subset_of(long))
  assert_false(long.is_subset_of(short))
}

///|
test "scalable counting subset rejects non-empty slices beyond the other filter" {
  let short = ScalableCountingBloomFilter::new(2, 0.01)
  short.insert("kept-a")
  short.insert("kept-b")
  let long = short.copy()
  for i = 0; i < 12; i = i + 1 {
    long.insert("extra-" + i.to_string())
  }
  assert_true(long.slice_count() > short.slice_count())
  assert_true(short.is_subset_of(long))
  assert_false(long.is_subset_of(short))
}

///|
test "scalable bloom disjointness treats different non-empty layouts as unknown" {
  let left = ScalableBloomFilter::new(1, 0.01)
  let right = ScalableBloomFilter::new(1, 0.01)
  left.insert("a-0")
  left.insert("left-extra")
  right.insert("b-15")
  right.insert("right-extra")
  assert_eq(left.slice_count(), 2)
  assert_eq(right.slice_count(), 2)
  assert_true(left.slices[0].is_disjoint_from(right.slices[0]))
  assert_false(left.is_disjoint_from(right))
  assert_false(right.is_disjoint_from(left))
}

///|
test "scalable counting disjointness treats different non-empty layouts as unknown" {
  let left = ScalableCountingBloomFilter::new(1, 0.01)
  let right = ScalableCountingBloomFilter::new(1, 0.01)
  left.insert("a-0")
  left.insert("left-extra")
  right.insert("b-15")
  right.insert("right-extra")
  assert_eq(left.slice_count(), 2)
  assert_eq(right.slice_count(), 2)
  assert_true(left.slices[0].is_disjoint_from(right.slices[0]))
  assert_false(left.is_disjoint_from(right))
  assert_false(right.is_disjoint_from(left))
}

///|
test "scalable counting contains_all reports a key missing from every slice" {
  let filter = ScalableCountingBloomFilter::new(2, 0.01)
  filter.insert_all(["a", "b", "c"])
  assert_false(filter.contains_all(["a", "definitely-missing"]))
  assert_true(filter.contains_all(["a", "b", "c"]))
}

///|
test "scalable bloom set operations ignore count-only empty slices" {
  let left = ScalableBloomFilter::new(2, 0.01)
  left.append_slice()
  left.slices[1].inserted = 5
  left.inserted = 5
  let right = ScalableBloomFilter::new(2, 0.01)
  assert_eq(left.slices[1].set_bit_count(), 0)
  assert_true(left.is_subset_of(right))
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
  right.append_slice()
  assert_true(left.is_disjoint_from(right))
}

///|
test "scalable counting set operations ignore count-only empty slices" {
  let left = ScalableCountingBloomFilter::new(2, 0.01)
  left.append_slice()
  left.slices[1].inserted = 5
  left.inserted = 5
  let right = ScalableCountingBloomFilter::new(2, 0.01)
  assert_eq(left.slices[1].occupied_slot_count(), 0)
  assert_true(left.is_subset_of(right))
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
  right.append_slice()
  assert_true(left.is_disjoint_from(right))
}

///|
test "scalable bloom disjointness skips empty slices between non-empty ones" {
  let left = ScalableBloomFilter::new(2, 0.01)
  left.append_slice()
  assert_eq(left.slices[0].set_bit_count(), 0)
  left.slices[1].insert("shared")
  left.inserted = 1

  let right = ScalableBloomFilter::new(2, 0.01)
  right.insert("other")
  right.append_slice()
  right.slices[1].insert("shared")
  right.inserted = 2
  assert_true(right.slices[0].set_bit_count() > 0)

  // The empty first slice is skipped in both directions, while the shared
  // second slice keeps the pair from being reported as definitely disjoint.
  assert_false(left.is_disjoint_from(right))
  assert_false(right.is_disjoint_from(left))
}

///|
test "scalable slice rates clamp underflow to the smallest positive double" {
  let smallest = 0x0000000000000001L.reinterpret_as_double()
  let target = @double.min_positive / 1.0e15
  assert_eq(scalable_slice_rate(target, 3), smallest)
  assert_eq(scalable_counting_slice_rate(target, 3), smallest)
  assert_true(scalable_slice_rate(target, 2) > 0.0)
  assert_true(scalable_counting_slice_rate(target, 2) > 0.0)
}

///|
test "merging a non-empty bloom filter into an empty grown receiver keeps slices" {
  let receiver = ScalableBloomFilter::new(2, 0.01)
  receiver.append_slice()
  receiver.append_slice()
  assert_eq(receiver.slice_count(), 3)
  assert_true(receiver.is_empty())
  let source = ScalableBloomFilter::new(2, 0.01)
  source.insert("source")
  receiver.merge(source)
  assert_eq(receiver.slice_count(), 3)
  assert_eq(receiver.count(), 1)
  assert_true(receiver.contains("source"))
  assert_eq(receiver.slices[1].set_bit_count(), 0)
  assert_eq(receiver.slices[2].set_bit_count(), 0)
  let restored = ScalableBloomFilter::from_bytes(receiver.to_bytes())
  assert_eq(restored.slice_count(), 3)
  assert_true(restored.contains("source"))
}
