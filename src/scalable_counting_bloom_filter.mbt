///|
/// A counting Bloom filter that grows by appending slices when the current
/// slice reaches its planned capacity.
///
/// Each slice doubles the previous capacity and halves its share of the target
/// false-positive rate. A key is always inserted into the slice where it was
/// first seen, so duplicates share counters and can be removed independently.
/// Slice assignments and exact insertion multiplicities are tracked to support
/// deletion; this metadata costs memory proportional to the number of distinct
/// keys inserted.
pub struct ScalableCountingBloomFilter {
  priv mut slices : Array[CountingBloomFilter]
  priv mut capacities : Array[Int32]
  priv locations : @hashmap.HashMap[(UInt64, UInt64), (Int32, Int32)]
  priv initial_capacity : Int32
  priv target_rate : Double
  priv mut inserted : Int32
}

///|
const SCALABLE_COUNTING_GROWTH : Int32 = 2

///|
fn scalable_counting_slice_rate(target_rate : Double, index : Int32) -> Double {
  let rate = target_rate * @math.pow(0.5, (index + 1).to_double())
  if rate > 0.0 {
    rate
  } else {
    target_rate
  }
}

///|
fn ScalableCountingBloomFilter::append_slice(
  self : ScalableCountingBloomFilter,
) -> Unit {
  let index = self.slices.length()
  let capacity = if index == 0 {
    self.initial_capacity
  } else {
    let previous = self.capacities[index - 1]
    if previous > 2147483647 / SCALABLE_COUNTING_GROWTH {
      abort("scalable counting bloom filter is too large")
    }
    previous * SCALABLE_COUNTING_GROWTH
  }
  let slice = CountingBloomFilter::new(
    capacity,
    scalable_counting_slice_rate(self.target_rate, index),
  )
  let mut bit_count = slice.slot_count().to_int64() * 16L
  for existing in self.slices {
    bit_count = bit_count + existing.slot_count().to_int64() * 16L
  }
  guard bit_count <= 2147483584L else {
    abort("scalable counting bloom filter is too large")
  }
  self.slices.push(slice)
  self.capacities.push(capacity)
}

///|
/// Create a growing counting filter sized for an initial `expected_items` keys
/// and the target `false_positive_rate`.
///
/// Panics if the capacity or rate is invalid or if the filter would exceed the
/// supported storage size.
pub fn ScalableCountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ScalableCountingBloomFilter {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  let filter : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity: expected_items,
    target_rate: false_positive_rate,
    inserted: 0,
  }
  filter.append_slice()
  filter
}

///|
fn ScalableCountingBloomFilter::ensure_room(
  self : ScalableCountingBloomFilter,
) -> Unit {
  let last = self.slices.length() - 1
  if self.slices[last].count() >= self.capacities[last] {
    self.append_slice()
  }
}

///|
/// Insert `key` into the slice that already owns it, or into the newest slice
/// for a new key.
///
/// Duplicate insertions increase the key's multiplicity and never trigger
/// slice growth. The insertion counter is incremented for every call.
pub fn[K : Hash] ScalableCountingBloomFilter::insert(
  self : ScalableCountingBloomFilter,
  key : K,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("scalable counting bloom filter insertion count overflow")
  }
  let id = key_hashes(key)
  match self.locations.get(id) {
    Some((slice_index, occurrences)) => {
      guard occurrences < 2147483647 else {
        abort("scalable counting bloom filter occurrence count overflow")
      }
      self.slices[slice_index].insert(key)
      self.locations.set(id, (slice_index, occurrences + 1))
    }
    None => {
      self.ensure_room()
      let slice_index = self.slices.length() - 1
      self.slices[slice_index].insert(key)
      self.locations.set(id, (slice_index, 1))
    }
  }
  self.inserted += 1
}

///|
/// Insert `key` only when no slice reports it present.
///
/// Returns `true` when the key was inserted. A false positive in any slice can
/// suppress the insertion.
pub fn[K : Hash] ScalableCountingBloomFilter::insert_if_absent(
  self : ScalableCountingBloomFilter,
  key : K,
) -> Bool {
  if self.contains(key) {
    return false
  }
  self.insert(key)
  true
}

///|
/// Test whether any slice may contain `key`.
pub fn[K : Hash] ScalableCountingBloomFilter::contains(
  self : ScalableCountingBloomFilter,
  key : K,
) -> Bool {
  let mut index = self.slices.length() - 1
  while index >= 0 {
    if self.slices[index].contains(key) {
      return true
    }
    index = index - 1
  }
  false
}

///|
/// Return the exact number of tracked insertions of `key`.
///
/// Returns `0` for a key that has never been inserted, even when `contains`
/// reports a false positive. Counters in the backing slices are still subject
/// to saturation and false positives; this value tracks calls made through
/// this filter.
pub fn[K : Hash] ScalableCountingBloomFilter::count_of(
  self : ScalableCountingBloomFilter,
  key : K,
) -> Int32 {
  match self.locations.get(key_hashes(key)) {
    Some((_, occurrences)) => occurrences
    None => 0
  }
}

///|
/// Remove one tracked insertion of `key`.
///
/// Returns `false` when the key is not tracked or when its counters could not
/// be decremented. Removing a key that was never inserted does not corrupt the
/// filter.
pub fn[K : Hash] ScalableCountingBloomFilter::remove(
  self : ScalableCountingBloomFilter,
  key : K,
) -> Bool {
  let id = key_hashes(key)
  let (slice_index, occurrences) = match self.locations.get(id) {
    Some(location) => location
    None => return false
  }
  if self.slices[slice_index].remove(key) {
    if occurrences > 1 {
      self.locations.set(id, (slice_index, occurrences - 1))
    } else {
      self.locations.remove(id)
    }
    self.refresh_inserted()
    return true
  }
  for index = 0; index < self.slices.length(); index = index + 1 {
    if index == slice_index {
      continue
    }
    if self.slices[index].remove(key) {
      if occurrences > 1 {
        self.locations.set(id, (index, occurrences - 1))
      } else {
        self.locations.remove(id)
      }
      self.refresh_inserted()
      return true
    }
  }
  false
}

///|
/// Keep the global insertion count consistent with the slice counters after a
/// removal. Counter collisions can make an individual slice keep a saturated
/// residue, so the total is recomputed instead of decremented blindly.
fn ScalableCountingBloomFilter::refresh_inserted(
  self : ScalableCountingBloomFilter,
) -> Unit {
  let mut total = 0
  for slice in self.slices {
    total = total + slice.count()
  }
  self.inserted = total
}

///|
/// Insert every key in `keys`, growing the filter as needed.
pub fn[K : Hash] ScalableCountingBloomFilter::insert_all(
  self : ScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  for key in keys {
    self.insert(key)
  }
}

///|
/// Insert every key that is definitely absent and return how many were added.
pub fn[K : Hash] ScalableCountingBloomFilter::insert_all_if_absent(
  self : ScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Int32 {
  let mut added = 0
  for key in keys {
    if self.insert_if_absent(key) {
      added = added + 1
    }
  }
  added
}

///|
/// Remove one tracked insertion of every key in `keys`.
///
/// Continues after a key cannot be removed and returns `true` only when every
/// removal succeeded.
pub fn[K : Hash] ScalableCountingBloomFilter::remove_all(
  self : ScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  let mut removed_all = true
  for key in keys {
    if !self.remove(key) {
      removed_all = false
    }
  }
  removed_all
}

///|
/// Test every key in `keys`, stopping at the first definite miss.
pub fn[K : Hash] ScalableCountingBloomFilter::contains_all(
  self : ScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  for key in keys {
    if !self.contains(key) {
      return false
    }
  }
  true
}

///|
/// Test whether at least one key in `keys` may be present.
pub fn[K : Hash] ScalableCountingBloomFilter::contains_any(
  self : ScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  for key in keys {
    if self.contains(key) {
      return true
    }
  }
  false
}

///|
/// Return an independent copy of the filter, including slices and location
/// metadata.
pub fn ScalableCountingBloomFilter::copy(
  self : ScalableCountingBloomFilter,
) -> ScalableCountingBloomFilter {
  let slices : Array[CountingBloomFilter] = []
  for slice in self.slices {
    slices.push(slice.copy())
  }
  let capacities : Array[Int32] = []
  for capacity in self.capacities {
    capacities.push(capacity)
  }
  {
    slices,
    capacities,
    locations: self.locations.copy(),
    initial_capacity: self.initial_capacity,
    target_rate: self.target_rate,
    inserted: self.inserted,
  }
}

///|
/// Remove every slice and tracked key, then restart with one empty slice using
/// the original initial capacity and target rate.
pub fn ScalableCountingBloomFilter::clear(
  self : ScalableCountingBloomFilter,
) -> Unit {
  self.slices = []
  self.capacities = []
  self.locations.clear()
  self.inserted = 0
  self.append_slice()
}

///|
/// Number of insertions observed since creation or the last `clear`.
pub fn ScalableCountingBloomFilter::count(
  self : ScalableCountingBloomFilter,
) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion has happened since creation or the last `clear`.
pub fn ScalableCountingBloomFilter::is_empty(
  self : ScalableCountingBloomFilter,
) -> Bool {
  self.inserted == 0
}

///|
/// Number of distinct keys currently tracked for deletion.
pub fn ScalableCountingBloomFilter::tracked_key_count(
  self : ScalableCountingBloomFilter,
) -> Int32 {
  self.locations.length()
}

///|
/// Number of slices currently backing the filter.
pub fn ScalableCountingBloomFilter::slice_count(
  self : ScalableCountingBloomFilter,
) -> Int32 {
  self.slices.length()
}

///|
/// Sum of the planned capacities of the current slices.
pub fn ScalableCountingBloomFilter::capacity(
  self : ScalableCountingBloomFilter,
) -> Int64 {
  let mut total = 0L
  for capacity in self.capacities {
    total = total + capacity.to_int64()
  }
  total
}

///|
/// Number of counter slots across all slices.
pub fn ScalableCountingBloomFilter::slot_count(
  self : ScalableCountingBloomFilter,
) -> Int64 {
  let mut total = 0L
  for slice in self.slices {
    total = total + slice.slot_count().to_int64()
  }
  total
}

///|
/// Number of non-zero counter slots across all slices.
pub fn ScalableCountingBloomFilter::occupied_slot_count(
  self : ScalableCountingBloomFilter,
) -> Int64 {
  let mut total = 0L
  for slice in self.slices {
    total = total + slice.occupied_slot_count().to_int64()
  }
  total
}

///|
/// Fraction of counter slots currently non-zero, in `[0, 1]`.
pub fn ScalableCountingBloomFilter::fill_ratio(
  self : ScalableCountingBloomFilter,
) -> Double {
  self.occupied_slot_count().to_double() / self.slot_count().to_double()
}

///|
/// Estimate the number of distinct keys represented by the current counters.
pub fn ScalableCountingBloomFilter::estimated_item_count(
  self : ScalableCountingBloomFilter,
) -> Double {
  let mut total = 0.0
  for slice in self.slices {
    total = total + slice.estimated_item_count()
  }
  total
}

///|
/// Target false-positive rate requested at construction time.
pub fn ScalableCountingBloomFilter::target_false_positive_rate(
  self : ScalableCountingBloomFilter,
) -> Double {
  self.target_rate
}

///|
/// Estimated current false-positive rate across all slices.
pub fn ScalableCountingBloomFilter::false_positive_rate(
  self : ScalableCountingBloomFilter,
) -> Double {
  let mut miss_rate = 1.0
  for slice in self.slices {
    miss_rate = miss_rate * (1.0 - slice.false_positive_rate())
  }
  1.0 - miss_rate
}

///|
/// Number of bytes occupied by the counter arrays of all slices, excluding
/// location metadata.
pub fn ScalableCountingBloomFilter::memory_bytes(
  self : ScalableCountingBloomFilter,
) -> Int64 {
  let mut total = 0L
  for slice in self.slices {
    total = total + slice.memory_bytes()
  }
  total
}

///|
fn ScalableCountingBloomFilter::ensure_same_policy(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Unit {
  guard self.initial_capacity == other.initial_capacity &&
    self.target_rate == other.target_rate else {
    abort(
      "scalable counting bloom filters must share the initial capacity and target rate",
    )
  }
}

///|
/// Merge every slice and tracked key of `other` into `self` in place.
///
/// Both filters must share the same initial capacity and target rate, so slice
/// `i` of each filter uses the same layout and their counters are combined with
/// the larger value. Slices that only `other` holds are appended as copies, and
/// tracked multiplicities are combined per key. The insertion counter becomes
/// the sum of the input counts, a conservative upper bound when keys overlap.
pub fn ScalableCountingBloomFilter::merge(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Unit {
  self.ensure_same_policy(other)
  guard self.inserted <= 2147483647 - other.inserted else {
    abort("scalable counting bloom filter insertion count overflow")
  }
  let mut total_slots = self.slot_count()
  for i = self.slices.length(); i < other.slices.length(); i = i + 1 {
    total_slots = total_slots + other.slices[i].slot_count().to_int64()
  }
  guard total_slots * 16L <= 2147483584L else {
    abort("scalable counting bloom filter is too large")
  }
  for i = 0; i < other.slices.length(); i = i + 1 {
    if i < self.slices.length() {
      self.slices[i].merge(other.slices[i])
    } else {
      self.slices.push(other.slices[i].copy())
      self.capacities.push(other.capacities[i])
    }
  }
  let merged : @hashmap.HashMap[(UInt64, UInt64), (Int32, Int32)] = @hashmap.HashMap([],
  )
  for entry in self.locations.iter() {
    merged.set(entry.0, entry.1)
  }
  for entry in other.locations.iter() {
    let (id, (other_slice, other_occurrences)) = entry
    match merged.get(id) {
      Some((self_slice, self_occurrences)) =>
        if self_slice == other_slice {
          merged.set(
            id,
            (
              self_slice,
              if self_occurrences > other_occurrences {
                self_occurrences
              } else {
                other_occurrences
              },
            ),
          )
        } else {
          guard self_occurrences <= 2147483647 - other_occurrences else {
            abort("scalable counting bloom filter occurrence count overflow")
          }
          merged.set(id, (self_slice, self_occurrences + other_occurrences))
        }
      None => merged.set(id, (other_slice, other_occurrences))
    }
  }
  self.locations.clear()
  for entry in merged.iter() {
    self.locations.set(entry.0, entry.1)
  }
  self.inserted += other.inserted
}

///|
/// Build a new filter containing every key present in either input.
///
/// Both filters must share the same initial capacity and target rate. The
/// result uses the per-slice union of their counters, so it never reports a
/// false negative for a key either input reported present. The inputs are left
/// unchanged.
pub fn ScalableCountingBloomFilter::union(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> ScalableCountingBloomFilter {
  let result = self.copy()
  result.merge(other)
  result
}

///|
/// Whether every key reported present by `self` is also reported present by
/// `other`.
///
/// Both filters must share the same initial capacity and target rate. Slice `i`
/// of `self` is compared only against slice `i` of `other` because slices with
/// different indices use different layouts; a slice of `self` beyond the last
/// slice of `other` must be empty. A `true` result is therefore sufficient but
/// not necessary for membership containment: a key missed by its own slice in
/// `other` could still be covered by another slice.
pub fn ScalableCountingBloomFilter::is_subset_of(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Bool {
  self.ensure_same_policy(other)
  for i = 0; i < self.slices.length(); i = i + 1 {
    if i < other.slices.length() {
      if !self.slices[i].is_subset_of(other.slices[i]) {
        return false
      }
    } else if self.slices[i].occupied_slot_count() > 0 {
      return false
    }
  }
  true
}

///|
/// Whether `self` and `other` are definitely disjoint.
///
/// Both filters must share the same initial capacity and target rate. Returns
/// `true` only when every slice of `self` has no positive counter in common with
/// every slice of `other`. A key can only be reported by both filters when its
/// counters are positive in one slice of each, so this guarantees no key is
/// reported present by both. A `false` result is inconclusive because equal
/// counters may come from different keys.
///
/// Slices at different indices use different layouts, so their counter arrays
/// cannot be compared directly. A pair of slices with different layouts is
/// treated as not provably disjoint once both are non-empty; an empty slice
/// never reports any key and therefore cannot overlap.
pub fn ScalableCountingBloomFilter::is_disjoint_from(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Bool {
  self.ensure_same_policy(other)
  for left in self.slices {
    for right in other.slices {
      if left.occupied_slot_count() > 0 && right.occupied_slot_count() > 0 {
        if left.slot_count() != right.slot_count() ||
          left.hash_count() != right.hash_count() {
          return false
        }
        if !left.is_disjoint_from(right) {
          return false
        }
      }
    }
  }
  true
}
