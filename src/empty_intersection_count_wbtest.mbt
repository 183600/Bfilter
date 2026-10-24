///|
test "bloom empty intersections keep the smaller conservative count" {
  let count_only = BloomFilter::with_size(512, 4)
  count_only.inserted = 7
  // A count-only state is reachable through deserialization: the encoding
  // accepts a positive insertion count when no bit is set.
  let restored = BloomFilter::from_bytes(count_only.to_bytes())
  assert_eq(restored.count(), 7)
  assert_eq(restored.set_bit_count(), 0)

  let other = BloomFilter::with_size(512, 4)
  other.insert_all(["kept", "kept"])
  let expected = restored.count().min(other.count())
  let forward = restored.intersection(other)
  let backward = other.intersection(restored)
  assert_eq(forward.count(), expected)
  assert_eq(backward.count(), expected)
  assert_eq(forward.set_bit_count(), 0)
  assert_eq(backward.set_bit_count(), 0)
  let round_trip = BloomFilter::from_bytes(forward.to_bytes())
  assert_eq(round_trip.count(), expected)
  assert_eq(round_trip.set_bit_count(), 0)
}

///|
test "blocked bloom empty intersections keep the smaller conservative count" {
  let count_only = BlockedBloomFilter::with_size(512, 4)
  count_only.inserted = 7
  let restored = BlockedBloomFilter::from_bytes(count_only.to_bytes())
  assert_eq(restored.count(), 7)
  assert_eq(restored.set_bit_count(), 0)

  let other = BlockedBloomFilter::with_size(512, 4)
  other.insert_all(["kept", "kept"])
  let expected = restored.count().min(other.count())
  let forward = restored.intersection(other)
  let backward = other.intersection(restored)
  assert_eq(forward.count(), expected)
  assert_eq(backward.count(), expected)
  assert_eq(forward.set_bit_count(), 0)
  assert_eq(backward.set_bit_count(), 0)
  let round_trip = BlockedBloomFilter::from_bytes(forward.to_bytes())
  assert_eq(round_trip.count(), expected)
  assert_eq(round_trip.set_bit_count(), 0)
}
