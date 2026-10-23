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

///|
test "scalable counting subset ignores drained keys that self no longer reports" {
  // A saturated key can remain tracked with a zero counter while the rest of
  // the filter still has live keys. Once `contains` is false for the drained
  // key, it must not block the membership subset check just because the other
  // filter never saw that key.
  let subset = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 65_536; i = i + 1 {
    subset.insert("hot")
  }
  for i = 0; i < 65_535; i = i + 1 {
    assert_true(subset.remove("hot"))
  }
  assert_false(subset.contains("hot"))
  assert_eq(subset.count_of("hot"), 1)
  subset.insert("live-a")
  subset.insert("live-b")
  assert_true(subset.contains("live-a"))
  assert_true(subset.contains("live-b"))
  assert_true(subset.slice_count() > 1)

  // Put the shared live keys in a later slice than `subset` so the per-slice
  // counter comparison is inconclusive and the tracked-key fallback runs.
  let other = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 4; i = i + 1 {
    other.insert("filler-" + i.to_string())
  }
  other.insert("live-a")
  other.insert("live-b")
  assert_true(other.contains("live-a"))
  assert_true(other.contains("live-b"))
  assert_false(other.contains("hot"))
  assert_true(other.slice_count() > subset.slice_count())
  assert_true(subset.is_subset_of(other))
}
