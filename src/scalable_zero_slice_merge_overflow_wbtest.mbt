///|
test "panic scalable bloom zero-slice merge rejects insertion count overflow" {
  let left : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 4,
    target_rate: 0.01,
    inserted: 2147483647,
  }
  let right : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 4,
    target_rate: 0.01,
    inserted: 1,
  }
  left.merge(right)
}
