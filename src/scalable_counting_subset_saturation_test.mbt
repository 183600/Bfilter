///|
test "scalable counting subset rejects a key whose counters drained" {
  let subset = @src.ScalableCountingBloomFilter::new(1, 0.5)
  subset.insert("shared")
  let saturated = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 65_536; i = i + 1 {
    saturated.insert("shared")
  }
  for i = 0; i < 65_535; i = i + 1 {
    assert_true(saturated.remove("shared"))
  }
  // Both filters still track one occurrence, but only the subset has a
  // positive counter for it. A subset check must follow membership, not just
  // the tracked multiplicity.
  assert_eq(subset.count_of("shared"), 1)
  assert_eq(saturated.count_of("shared"), 1)
  assert_true(subset.contains("shared"))
  assert_false(saturated.contains("shared"))
  assert_false(subset.is_subset_of(saturated))
  assert_true(saturated.is_subset_of(subset))
}
