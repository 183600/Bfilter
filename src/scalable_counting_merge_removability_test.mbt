///|
test "scalable counting merge keeps source keys removable after shared saturation" {
  let target = @src.ScalableCountingBloomFilter::new(1, 0.25)
  for i = 0; i < 65_535; i = i + 1 {
    target.insert(2)
  }
  let source = @src.ScalableCountingBloomFilter::new(1, 0.25)
  source.insert(0)
  source.insert(0)

  let combined = target.union(source)
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  for filter in [combined, restored] {
    assert_eq(filter.count_of(0), 2)
    assert_true(filter.contains(0))
    assert_true(filter.remove(0))
    assert_eq(filter.count_of(0), 1)
    assert_true(filter.remove(0))
    assert_eq(filter.count_of(0), 0)
    assert_false(filter.remove(0))
  }

  target.merge(source)
  assert_eq(target.count_of(0), 2)
  assert_true(target.contains(0))
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 1)
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 0)
  assert_false(target.remove(0))
  assert_eq(target.count_of(2), 65_535)
}

///|
test "scalable counting merge records unsaturated lanes when a shared lane is full" {
  let target = @src.ScalableCountingBloomFilter::new(2, 0.25)
  target.insert(0)
  for i = 0; i < 65_535; i = i + 1 {
    target.insert(2)
  }
  let source = @src.ScalableCountingBloomFilter::new(2, 0.25)
  source.insert(0)
  source.insert(0)
  source.insert(0)
  target.merge(source)
  assert_eq(target.count_of(0), 3)
  assert_true(target.contains(0))
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 2)
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 1)
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 0)
  assert_false(target.remove(0))
}

///|
test "scalable counting cross-slice merge records a single extra occurrence" {
  let target = @src.ScalableCountingBloomFilter::new(2, 0.25)
  target.insert(2)
  target.insert(0)
  target.insert(0)
  for i = 0; i < 65_535; i = i + 1 {
    target.insert(2)
  }
  let source = @src.ScalableCountingBloomFilter::new(2, 0.25)
  source.insert(3)
  source.insert(4)
  source.insert(5)
  source.insert(0)
  assert_true(source.slice_count() > 1)
  target.merge(source)
  assert_eq(target.count_of(0), 3)
  assert_true(target.contains(0))
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 2)
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 1)
  assert_true(target.remove(0))
  assert_eq(target.count_of(0), 0)
  assert_false(target.remove(0))
}
