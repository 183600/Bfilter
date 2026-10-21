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
fn scalable_counting_slice_rate(
  target_rate : Double,
  index : Int32,
) -> Double {
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
  if !self.slices[slice_index].remove(key) {
    return false
  }
  if occurrences > 1 {
    self.locations.set(id, (slice_index, occurrences - 1))
  } else {
    self.locations.remove(id)
  }
  if self.inserted > 0 {
    self.inserted -= 1
  }
  true
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
