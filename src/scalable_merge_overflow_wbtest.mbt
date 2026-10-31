///|
test "panic scalable bloom empty merge rejects count-only source overflow" {
  let receiver = ScalableBloomFilter::new(4, 0.01)
  receiver.slices[0].inserted = 2147483647
  receiver.inserted = 0
  let source = ScalableBloomFilter::new(4, 0.01)
  source.slices = []
  source.capacities = []
  source.inserted = 1
  receiver.merge(source)
}

///|
test "panic scalable bloom non-empty merge rejects count-only source overflow" {
  let receiver = ScalableBloomFilter::new(4, 0.01)
  receiver.slices[0].inserted = 2147483647
  receiver.inserted = 1
  let source = ScalableBloomFilter::new(4, 0.01)
  source.slices = []
  source.capacities = []
  source.inserted = 1
  receiver.merge(source)
}

///|
test "panic scalable bloom intersection rejects aggregate bit overflow" {
  let left = ScalableBloomFilter::new(4, 0.01)
  left.append_slice()
  left.slices[0] = {
    words: FixedArray::make(1, 0UL),
    bit_count: 1073741824,
    hash_count: 1,
    inserted: 0,
  }
  left.slices[1] = {
    words: FixedArray::make(1, 0UL),
    bit_count: 1073741824,
    hash_count: 1,
    inserted: 0,
  }
  let right = ScalableBloomFilter::new(4, 0.01)
  right.append_slice()
  left.intersection(right) |> ignore
}

///|
test "panic scalable counting merge rejects oversized count-only source" {
  let receiver = ScalableCountingBloomFilter::new(4, 0.01)
  let source = ScalableCountingBloomFilter::new(4, 0.01)
  source.append_slice()
  let slice = source.slices[1]
  source.slices[1] = {
    counters: slice.counters,
    slot_count: SCALABLE_COUNTING_MAX_SLOTS.to_int(),
    hash_count: slice.hash_count,
    inserted: slice.inserted,
    counter_mass: slice.counter_mass,
    probe_positions: slice.probe_positions,
    probe_counts: slice.probe_counts,
  }
  receiver.merge(source)
}

///|
test "panic scalable counting merge rejects oversized count-only receiver" {
  let receiver = ScalableCountingBloomFilter::new(4, 0.01)
  receiver.append_slice()
  let slice = receiver.slices[1]
  receiver.slices[1] = {
    counters: slice.counters,
    slot_count: SCALABLE_COUNTING_MAX_SLOTS.to_int(),
    hash_count: slice.hash_count,
    inserted: slice.inserted,
    counter_mass: slice.counter_mass,
    probe_positions: slice.probe_positions,
    probe_counts: slice.probe_counts,
  }
  receiver.inserted = 1
  let source = ScalableCountingBloomFilter::new(4, 0.01)
  source.insert("tracked")
  assert_eq(source.slice_count(), 1)
  receiver.merge(source)
}
