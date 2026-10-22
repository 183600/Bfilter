///|
test "panic scalable bloom intersection rejects an overflowing count total" {
  let left = ScalableBloomFilter::new(2, 0.01)
  let right = ScalableBloomFilter::new(2, 0.01)
  left.append_slice()
  right.append_slice()
  // Hand-build slice counts whose sum cannot be represented by the 32-bit
  // insertion counter even though each individual slice count fits.
  left.slices[0].inserted = 1_500_000_000
  left.slices[1].inserted = 1_500_000_000
  right.slices[0].inserted = 1_500_000_000
  right.slices[1].inserted = 1_500_000_000
  left.inserted = 2_147_483_647
  right.inserted = 2_147_483_647
  left.intersection(right) |> ignore
}

///|
test "panic scalable counting intersection rejects an overflowing count total" {
  let left = ScalableCountingBloomFilter::new(2, 0.01)
  let right = ScalableCountingBloomFilter::new(2, 0.01)
  // Two tracked keys each claim more than half of the supported insertion
  // count, so rebuilding the intersection result would wrap its counter.
  left.locations.set((1UL, 1UL), (0, 1_500_000_000))
  left.locations.set((2UL, 3UL), (0, 1_500_000_000))
  right.locations.set((1UL, 1UL), (0, 1_500_000_000))
  right.locations.set((2UL, 3UL), (0, 1_500_000_000))
  left.inserted = 2_147_483_647
  right.inserted = 2_147_483_647
  left.intersection(right) |> ignore
}
