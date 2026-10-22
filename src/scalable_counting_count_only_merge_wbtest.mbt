///|
/// Build a valid count-only state: an insertion count with no tracked key and no
/// positive counter.
fn count_only_scalable(
  receiver : ScalableCountingBloomFilter,
  count : Int32,
) -> Unit {
  receiver.slices[receiver.slices.length() - 1].inserted = count
  receiver.inserted = count
}

///|
/// Build a valid drained tracking state: a tracked key whose counters were
/// removed after saturation, so `contains` is false while the multiplicity is
/// still tracked.
fn drained_tracked_scalable(
  filter : ScalableCountingBloomFilter,
  key : String,
  occurrences : Int32,
) -> Unit {
  filter.locations.set(key_hashes(key), (0, occurrences))
  filter.slices[0].inserted = occurrences
  filter.inserted = occurrences
}

///|
test "merging a count-only source preserves a saturated receiver" {
  let receiver = ScalableCountingBloomFilter::new(1, 0.5)
  drained_tracked_scalable(receiver, "hot", 4_465)
  assert_false(receiver.contains("hot"))
  assert_eq(receiver.occupied_slot_count(), 0L)
  let before = receiver.to_bytes()
  let count = receiver.count()
  let tracked = receiver.tracked_key_count()

  let source = ScalableCountingBloomFilter::new(1, 0.5)
  count_only_scalable(source, 3)
  assert_eq(source.tracked_key_count(), 0)
  assert_eq(source.occupied_slot_count(), 0L)

  receiver.merge(source)
  assert_eq(receiver.to_bytes(), before)
  assert_eq(receiver.count(), count)
  assert_eq(receiver.tracked_key_count(), tracked)
  assert_eq(receiver.occupied_slot_count(), 0L)
  assert_false(receiver.contains("hot"))

  let combined = receiver.union(source)
  assert_eq(combined.to_bytes(), before)
  assert_eq(combined.count(), count)
  assert_false(combined.contains("hot"))
}

///|
test "merging a saturated source into a count-only receiver copies it" {
  let source = ScalableCountingBloomFilter::new(1, 0.5)
  drained_tracked_scalable(source, "hot", 4_465)
  assert_false(source.contains("hot"))
  assert_eq(source.occupied_slot_count(), 0L)
  let source_bytes = source.to_bytes()

  let receiver = ScalableCountingBloomFilter::new(1, 0.5)
  count_only_scalable(receiver, 2)
  assert_eq(receiver.tracked_key_count(), 0)
  assert_eq(receiver.occupied_slot_count(), 0L)

  receiver.merge(source)
  assert_eq(receiver.to_bytes(), source_bytes)
  assert_eq(receiver.count(), source.count())
  assert_eq(receiver.tracked_key_count(), source.tracked_key_count())
  assert_eq(receiver.occupied_slot_count(), 0L)
  assert_false(receiver.contains("hot"))
  assert_eq(receiver.count_of("hot"), 4_465)

  let union_receiver = ScalableCountingBloomFilter::new(1, 0.5)
  count_only_scalable(union_receiver, 2)
  let combined = union_receiver.union(source)
  assert_eq(combined.to_bytes(), source_bytes)
  assert_eq(combined.count_of("hot"), 4_465)
  assert_false(combined.contains("hot"))

  let restored = ScalableCountingBloomFilter::from_bytes(receiver.to_bytes())
  assert_eq(restored.to_bytes(), source_bytes)
  assert_eq(restored.count_of("hot"), 4_465)
  assert_false(restored.contains("hot"))
}

///|
test "count-only receiver keeps extra slices when merging a saturated source" {
  let source = ScalableCountingBloomFilter::new(1, 0.5)
  drained_tracked_scalable(source, "hot", 4_465)

  let receiver = ScalableCountingBloomFilter::new(1, 0.5)
  receiver.append_slice()
  receiver.slices[0].inserted = 2
  receiver.slices[1].inserted = 3
  receiver.inserted = 5
  assert_eq(receiver.tracked_key_count(), 0)
  assert_eq(receiver.occupied_slot_count(), 0L)

  receiver.merge(source)
  assert_eq(receiver.slice_count(), 2)
  // The source's only slice replaces the first receiver slice; the preserved
  // extra slice may not retain a phantom count-only insertion count.
  assert_eq(receiver.slices[0].inserted, source.slices[0].inserted)
  assert_eq(receiver.slices[1].inserted, 0)
  assert_eq(receiver.count(), source.count())
  assert_eq(receiver.tracked_key_count(), source.tracked_key_count())
  assert_eq(receiver.occupied_slot_count(), 0L)
  assert_false(receiver.contains("hot"))

  let restored = ScalableCountingBloomFilter::from_bytes(receiver.to_bytes())
  assert_eq(restored.slice_count(), 2)
  assert_eq(restored.count(), source.count())
  assert_eq(restored.count_of("hot"), 4_465)
  assert_false(restored.contains("hot"))
  assert_eq(restored.slices[0].to_bytes(), source.slices[0].to_bytes())
}
