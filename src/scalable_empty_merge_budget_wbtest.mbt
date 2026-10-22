///|
test "panic scalable bloom empty receiver merge checks combined bit budget" {
  let receiver = ScalableBloomFilter::new(2, 0.01)
  receiver.append_slice()
  receiver.append_slice()
  // Simulate an already-grown empty receiver whose newest slice pushes the
  // combined layout beyond the supported bit budget.
  receiver.slices[2] = {
    words: FixedArray::make(1, 0UL),
    bit_count: 2147483584,
    hash_count: 1,
    inserted: 0,
  }
  let source = ScalableBloomFilter::new(2, 0.01)
  source.insert("source")
  receiver.merge(source)
}
