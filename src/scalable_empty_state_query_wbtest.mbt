///|
/// A key whose custom `Hash` implementation counts how often a scalable filter
/// asks for its hash. Definitely empty scalable states must not hash.
struct ScalableHashProbe(Int32)

///|
let scalable_hash_probe_calls : @ref.Ref[Int32] = @ref.Ref(0)

///|
impl Hash for ScalableHashProbe with fn hash_combine(self, hasher) {
  scalable_hash_probe_calls.val = scalable_hash_probe_calls.val + 1
  hasher.combine_int(self.0)
}

///|
impl Hash for ScalableHashProbe with fn hash(self) {
  self.0
}

///|
test "zero-slice scalable bloom membership does not hash" {
  let filter : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  let key = ScalableHashProbe(7)
  scalable_hash_probe_calls.val = 0
  assert_false(filter.contains(key))
  assert_false(filter.contains_all([key]))
  assert_false(filter.contains_any([key]))
  assert_eq(scalable_hash_probe_calls.val, 0)
}

///|
test "count-only scalable counting membership does not hash" {
  let filter = ScalableCountingBloomFilter::new(2, 0.01)
  // Count-only filters carry a conservative insertion count without tracked
  // keys or positive counters. Every membership query is a definite miss.
  filter.slices[0].inserted = 5
  filter.inserted = 5
  assert_eq(filter.occupied_slot_count(), 0L)
  assert_eq(filter.tracked_key_count(), 0)
  let key = ScalableHashProbe(7)
  scalable_hash_probe_calls.val = 0
  assert_false(filter.contains(key))
  assert_false(filter.contains_all([key]))
  assert_false(filter.contains_any([key]))
  assert_eq(filter.count_of(key), 0)
  assert_false(filter.remove(key))
  assert_eq(scalable_hash_probe_calls.val, 0)
}
