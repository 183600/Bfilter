///|
test "panic scalable counting intersection checks aggregate slot budget" {
  let receiver = ScalableCountingBloomFilter::new(1, 0.01)
  // Simulate a slice whose metadata claims more counter slots than the
  // scalable filter is allowed to combine. The backing array stays small so
  // the budget check must run before any result slice is allocated.
  receiver.slices[0] = {
    counters: FixedArray::make(4, 0UL),
    slot_count: 1073741808,
    hash_count: 1,
    inserted: 0,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(1, 0),
    probe_counts: FixedArray::make(1, 0),
  }
  let other = ScalableCountingBloomFilter::new(1, 0.01)
  receiver.intersection(other) |> ignore
}
