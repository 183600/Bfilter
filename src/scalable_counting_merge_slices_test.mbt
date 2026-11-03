///|
/// Regression test: merging two scalable counting filters whose slice counts
/// differ must not index out of bounds. The filter with more slices can hold
/// tracked keys in slice indices beyond the other filter's slice count.
///|
test "scalable counting merge handles differing slice counts" {
  let self_filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  for i = 0; i < 6; i = i + 1 {
    self_filter.insert("self-" + i.to_string())
  }
  let other_filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
  for i = 0; i < 14; i = i + 1 {
    other_filter.insert("other-" + i.to_string())
  }
  assert_true(self_filter.slice_count() >= 2)
  assert_true(other_filter.slice_count() >= 3)
  // Merge in both directions must not panic.
  let merged = self_filter.copy()
  merged.merge(other_filter)
  for i = 0; i < 14; i = i + 1 {
    assert_true(merged.contains("other-" + i.to_string()))
  }
  let merged2 = other_filter.copy()
  merged2.merge(self_filter)
  for i = 0; i < 6; i = i + 1 {
    assert_true(merged2.contains("self-" + i.to_string()))
  }
}
