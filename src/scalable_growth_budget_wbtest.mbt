///|
test "panic scalable bloom growth checks the combined bit budget before allocating" {
  let filter = ScalableBloomFilter::new(2, 0.01)
  // Simulate a receiver that already holds nearly the whole supported bit
  // budget. Appending the next slice must fail from the combined-size guard
  // instead of allocating the slice first.
  filter.slices[0] = {
    words: FixedArray::make(1, 0UL),
    bit_count: 2147483584,
    hash_count: 1,
    inserted: 0,
  }
  filter.append_slice()
}
