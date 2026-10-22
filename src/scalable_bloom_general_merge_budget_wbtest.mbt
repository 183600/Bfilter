///|
/// Build a receiver whose aggregate bit count exceeds the supported budget but
/// whose `inserted` count is nonzero, so a merge takes the general path instead
/// of the empty-receiver copy fast path.
fn oversized_grown_bloom_receiver() -> ScalableBloomFilter {
  let receiver = ScalableBloomFilter::new(2, 0.01)
  receiver.append_slice()
  receiver.append_slice()
  receiver.slices[0].insert("grown")
  receiver.inserted = 1
  receiver.slices[2] = {
    words: FixedArray::make(1, 0UL),
    bit_count: 2147483584,
    hash_count: 1,
    inserted: 0,
  }
  receiver
}

///|
test "panic scalable bloom general merge checks combined bit budget" {
  let receiver = oversized_grown_bloom_receiver()
  let source = ScalableBloomFilter::new(2, 0.01)
  source.insert("source")
  receiver.merge(source)
}

///|
test "panic scalable bloom bit count rejects an oversized aggregate" {
  let receiver = oversized_grown_bloom_receiver()
  receiver.bit_count() |> ignore
}

///|
test "panic scalable bloom intersection checks aggregate bit budget" {
  let receiver = oversized_grown_bloom_receiver()
  let other = ScalableBloomFilter::new(2, 0.01)
  other.append_slice()
  other.append_slice()
  other.slices[0].insert("other")
  other.inserted = 1
  receiver.intersection(other) |> ignore
}

///|
test "panic scalable bloom serialization checks aggregate bit budget" {
  let receiver = oversized_grown_bloom_receiver()
  receiver.to_bytes() |> ignore
}

///|
test "scalable bloom intersection ignores oversized extra slices" {
  let receiver = oversized_grown_bloom_receiver()
  let other = ScalableBloomFilter::new(2, 0.01)
  other.insert("other")
  let common = receiver.intersection(other)
  assert_eq(common.slice_count(), 1)
  assert_eq(common.count(), 1)
}
