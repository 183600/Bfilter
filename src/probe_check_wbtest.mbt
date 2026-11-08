///|
fn probe_fill_count_only(
  filter : ScalableCountingBloomFilter,
  counts : Array[Int32],
  total : Int32,
) -> Unit {
  filter.slices = []
  filter.capacities = []
  filter.locations.clear()
  filter.inserted = 0
  filter.append_slice()
  for i = 1; i < counts.length(); i = i + 1 { filter.append_slice() }
  for i = 0; i < counts.length(); i = i + 1 {
    filter.slices[i].inserted = counts[i]
  }
  filter.inserted = total
}

///|
test "probe merge of tracked receiver and count-only source stays serializable" {
  let receiver = ScalableCountingBloomFilter::new(2, 0.5)
  receiver.insert("alpha")
  receiver.insert("beta")
  let source = ScalableCountingBloomFilter::new(2, 0.5)
  probe_fill_count_only(source, [1], 1)
  let merged = receiver.copy()
  merged.merge(source)
  assert_eq(merged.count(), 3)
  assert_eq(merged.tracked_key_count(), 2)
  assert_eq(merged.slice_count(), 2)
  let bytes = merged.to_bytes()
  let restored = ScalableCountingBloomFilter::from_bytes(bytes)
  assert_eq(restored.count(), merged.count())
}
