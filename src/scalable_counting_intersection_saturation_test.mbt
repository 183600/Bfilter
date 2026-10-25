///|
test "scalable counting intersection drops drained tracked keys" {
  let drained = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 65_536; i = i + 1 {
    drained.insert("hot")
  }
  for i = 0; i < 65_535; i = i + 1 {
    assert_true(drained.remove("hot"))
  }
  assert_false(drained.contains("hot"))
  assert_eq(drained.count_of("hot"), 1)
  drained.insert("kept")
  assert_true(drained.contains("kept"))

  let live = @src.ScalableCountingBloomFilter::new(1, 0.5)
  live.insert("hot")
  live.insert("kept")
  assert_true(live.contains("hot"))
  assert_true(live.contains("kept"))

  let common = drained.intersection(live)
  assert_false(common.contains("hot"))
  assert_eq(common.count_of("hot"), 0)
  assert_true(common.contains("kept"))
  assert_eq(common.count_of("kept"), 1)
  assert_true(common.is_subset_of(drained))
  assert_true(common.is_subset_of(live))

  let backward = live.intersection(drained)
  assert_false(backward.contains("hot"))
  assert_eq(backward.count_of("hot"), 0)
  assert_true(backward.contains("kept"))
  assert_eq(backward.count_of("kept"), 1)
  assert_true(backward.is_subset_of(drained))
  assert_true(backward.is_subset_of(live))
}
