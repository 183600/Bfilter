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
