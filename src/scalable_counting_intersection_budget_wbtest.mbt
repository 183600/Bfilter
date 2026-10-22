///|
/// Build a filter whose slice metadata claims more counter slots than the
/// scalable filter is allowed to combine while keeping the backing array small.
fn oversized_counting_slot_receiver() -> ScalableCountingBloomFilter {
  let receiver = ScalableCountingBloomFilter::new(1, 0.01)
  receiver.slices[0] = {
    counters: FixedArray::make(4, 0UL),
    slot_count: 1073741808,
    hash_count: 1,
    inserted: 0,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(1, 0),
    probe_counts: FixedArray::make(1, 0),
  }
  receiver
}

///|
test "panic scalable counting intersection checks aggregate slot budget" {
  let receiver = oversized_counting_slot_receiver()
  let other = ScalableCountingBloomFilter::new(1, 0.01)
  receiver.intersection(other) |> ignore
}

///|
test "panic scalable counting serialization checks aggregate slot budget" {
  let receiver = oversized_counting_slot_receiver()
  receiver.to_bytes() |> ignore
}

///|
test "scalable counting intersection ignores oversized extra slices" {
  let receiver = ScalableCountingBloomFilter::new(1, 0.01)
  receiver.append_slice()
  receiver.slices[1] = {
    counters: FixedArray::make(4, 0UL),
    slot_count: 1073741808,
    hash_count: 1,
    inserted: 0,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(1, 0),
    probe_counts: FixedArray::make(1, 0),
  }
  receiver.slices[0].insert("receiver")
  receiver.inserted = 1
  let other = ScalableCountingBloomFilter::new(1, 0.01)
  other.insert("other")
  let common = receiver.intersection(other)
  assert_eq(common.slice_count(), 1)
  assert_eq(common.count(), 0)
}
