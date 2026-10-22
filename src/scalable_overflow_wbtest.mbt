///|
test "panic scalable bloom growth rejects capacity overflow" {
  let filter = ScalableBloomFilter::new(1, 0.01)
  filter.capacities[0] = 2147483647
  filter.slices[0].inserted = 2147483647
  filter.insert("overflow")
}

///|
test "panic scalable counting growth rejects capacity overflow" {
  let filter = ScalableCountingBloomFilter::new(1, 0.01)
  filter.capacities[0] = 2147483647
  filter.slices[0].inserted = 2147483647
  filter.insert("overflow")
}

///|
test "panic scalable bloom growth checks the aggregate bit budget" {
  let filter = ScalableBloomFilter::new(1, 0.01)
  filter.append_slice()
  filter.slices[1] = {
    words: FixedArray::make(1, 0UL),
    bit_count: 2147483584,
    hash_count: 1,
    inserted: 2,
  }
  filter.inserted = 2
  filter.insert("overflow")
}

///|
test "panic scalable counting growth checks the aggregate slot budget" {
  let filter = ScalableCountingBloomFilter::new(1, 0.01)
  filter.append_slice()
  filter.slices[1] = {
    counters: FixedArray::make(4, 0UL),
    slot_count: SCALABLE_COUNTING_MAX_SLOTS.to_int(),
    hash_count: 1,
    inserted: 2,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(1, 0),
    probe_counts: FixedArray::make(1, 0),
  }
  filter.inserted = 2
  filter.insert("overflow")
}

///|
test "panic scalable counting duplicate insert rejects occurrence overflow" {
  let filter = ScalableCountingBloomFilter::new(1, 0.01)
  filter.insert("tracked")
  let id = key_hashes("tracked")
  let slice_index = match filter.locations.get(id) {
    Some((index, _)) => index
    None => abort("tracked key is missing")
  }
  filter.locations.set(id, (slice_index, 2147483647))
  filter.insert("tracked")
}

///|
test "panic scalable counting cross-slice merge rejects occurrence overflow" {
  let receiver = ScalableCountingBloomFilter::new(1, 0.01)
  receiver.insert("first")
  receiver.insert("second")
  receiver.insert("shared")
  let other = ScalableCountingBloomFilter::new(1, 0.01)
  other.insert("shared")
  let id = key_hashes("shared")
  let receiver_slice = match receiver.locations.get(id) {
    Some((index, _)) => index
    None => abort("receiver key is missing")
  }
  let other_slice = match other.locations.get(id) {
    Some((index, _)) => index
    None => abort("source key is missing")
  }
  assert_true(receiver_slice != other_slice)
  receiver.locations.set(id, (receiver_slice, 2147483647))
  other.locations.set(id, (other_slice, 2))
  receiver.merge(other)
}

///|
test "panic scalable counting general merge checks the aggregate slot budget" {
  let receiver : ScalableCountingBloomFilter = {
    slices: [
      {
        counters: FixedArray::make(4, 0UL),
        slot_count: SCALABLE_COUNTING_MAX_SLOTS.to_int() + 1,
        hash_count: 1,
        inserted: 0,
        counter_mass: 0UL,
        probe_positions: FixedArray::make(1, 0),
        probe_counts: FixedArray::make(1, 0),
      },
    ],
    capacities: [1],
    locations: @hashmap.HashMap([]),
    initial_capacity: 1,
    target_rate: 0.01,
    inserted: 1,
  }
  receiver.locations.set(key_hashes("receiver"), (0, 1))
  let source = ScalableCountingBloomFilter::new(1, 0.01)
  source.insert("source")
  receiver.merge(source)
}
