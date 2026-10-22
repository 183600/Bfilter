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
  priv mut locations : @hashmap.HashMap[(UInt64, UInt64), (Int32, Int32)]
  priv initial_capacity : Int32
  priv target_rate : Double
  priv mut inserted : Int32
}

///|
const SCALABLE_COUNTING_GROWTH : Int32 = 2

///|
/// Maximum number of counter slots a scalable counting filter can hold.
///
/// Counting filters store two bytes per slot. Growth doubles the capacity from
/// a positive initial capacity, so a filter can hold at most 31 slices before
/// the next capacity would overflow. The bound leaves room for the outer
/// serialization header, the length prefix and the 20-byte counter-filter
/// header of every slice, so any filter within it can encode its counter arrays
/// without overflowing the signed 32-bit serialized length. The per-slice
/// constructor still enforces its own limit.
const SCALABLE_COUNTING_MAX_SLOTS : Int64 = 1_073_741_435L

///|
fn scalable_counting_slice_rate(target_rate : Double, index : Int32) -> Double {
  let rate = target_rate * @math.pow(0.5, (index + 1).to_double())
  if rate > 0.0 {
    rate
  } else {
    // Halving a tiny target can underflow to zero. Keep every slice positive by
    // clamping to the smallest representable double instead of loosening the
    // later slices back to the original target rate.
    0x0000000000000001L.reinterpret_as_double()
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
  let (slot_count, hash_count) = counting_bloom_layout(
    capacity,
    scalable_counting_slice_rate(self.target_rate, index),
  )
  let mut total_slots = slot_count.to_int64()
  for existing in self.slices {
    total_slots = total_slots + existing.slot_count().to_int64()
  }
  guard total_slots <= SCALABLE_COUNTING_MAX_SLOTS else {
    abort("scalable counting bloom filter is too large")
  }
  let slice = CountingBloomFilter::with_size(slot_count, hash_count)
  self.slices.push(slice)
  self.capacities.push(capacity)
}

///|
/// Largest value a single backing 16-bit counter can hold.
pub fn ScalableCountingBloomFilter::counter_max() -> Int32 {
  CountingBloomFilter::counter_max()
}

///|
/// Compute the slot and hash counts of the first slice that
/// `ScalableCountingBloomFilter::new` would create, without allocating it.
///
/// The first slice uses half of the requested false-positive budget; later
/// slices keep halving it, so this helper is only a planning aid for the
/// initial allocation, not for the whole growing filter. Panics for the same
/// invalid arguments as `ScalableCountingBloomFilter::new`.
pub fn ScalableCountingBloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  let (slot_count, hash_count) = counting_bloom_layout(
    expected_items,
    scalable_counting_slice_rate(false_positive_rate, 0),
  )
  // The constructor rejects the first slice before allocating it when it would
  // already exceed the aggregate slot budget. Mirror that guard here so the
  // planner never advertises a layout that cannot be constructed.
  guard slot_count.to_int64() <= SCALABLE_COUNTING_MAX_SLOTS else {
    abort("scalable counting bloom filter is too large")
  }
  (slot_count, hash_count)
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
/// Insert a key whose two hash values have already been computed.
fn ScalableCountingBloomFilter::insert_hashes(
  self : ScalableCountingBloomFilter,
  id : (UInt64, UInt64),
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("scalable counting bloom filter insertion count overflow")
  }
  match self.locations.get(id) {
    Some((slice_index, occurrences)) => {
      guard occurrences < 2147483647 else {
        abort("scalable counting bloom filter occurrence count overflow")
      }
      self.slices[slice_index].insert_hashes(id.0, id.1)
      self.locations.set(id, (slice_index, occurrences + 1))
    }
    None => {
      // A count-only filter restored from bytes may carry conservative insertion
      // counts in its newest slice without any tracked key or positive counter.
      // Insert the first real key into a fresh slice so that slice's insertion
      // count stays exactly equal to its tracked occurrences; the older
      // count-only slices remain representable as conservative extras.
      if self.locations.length() == 0 && self.inserted > 0 {
        let last = self.slices.length() - 1
        if self.slices[last].count() > 0 {
          self.append_slice()
        }
      }
      self.ensure_room()
      let slice_index = self.slices.length() - 1
      self.slices[slice_index].insert_hashes(id.0, id.1)
      self.locations.set(id, (slice_index, 1))
    }
  }
  self.inserted += 1
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
  let id = key_hashes(key)
  self.insert_hashes(id)
}

///|
/// Insert `key` only when it is not tracked and no slice reports it present.
///
/// Returns `true` when the key was inserted. A tracked key is treated as
/// present even when its counters have drained after saturation, so this method
/// never adds another occurrence to a key that `count_of` still reports. A
/// false positive in any slice can also suppress the insertion.
pub fn[K : Hash] ScalableCountingBloomFilter::insert_if_absent(
  self : ScalableCountingBloomFilter,
  key : K,
) -> Bool {
  let id = key_hashes(key)
  if self.locations.contains(id) || self.contains_hashes(id) {
    return false
  }
  self.insert_hashes(id)
  true
}

///|
/// Test a key whose two hash values have already been computed.
fn ScalableCountingBloomFilter::contains_hashes(
  self : ScalableCountingBloomFilter,
  id : (UInt64, UInt64),
) -> Bool {
  let mut index = self.slices.length() - 1
  while index >= 0 {
    if self.slices[index].contains_hashes(id.0, id.1) {
      return true
    }
    index = index - 1
  }
  false
}

///|
/// Test whether any slice may contain `key`.
pub fn[K : Hash] ScalableCountingBloomFilter::contains(
  self : ScalableCountingBloomFilter,
  key : K,
) -> Bool {
  let id = key_hashes(key)
  self.contains_hashes(id)
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
  let slice = self.slices[slice_index]
  let before = slice.count()
  if slice.remove_hashes(id.0, id.1) {
    if occurrences > 1 {
      self.locations.set(id, (slice_index, occurrences - 1))
    } else {
      self.locations.remove(id)
    }
    self.inserted = self.inserted + slice.count() - before
    return true
  }
  false
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
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn ScalableCountingBloomFilter::count(
  self : ScalableCountingBloomFilter,
) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion is currently outstanding.
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
///
/// A hand-built filter with no slices has no counter slots, so the ratio is `0`
/// rather than `0 / 0`.
pub fn ScalableCountingBloomFilter::fill_ratio(
  self : ScalableCountingBloomFilter,
) -> Double {
  let slots = self.slot_count()
  if slots == 0L {
    0.0
  } else {
    self.occupied_slot_count().to_double() / slots.to_double()
  }
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
/// `i` of each filter uses the same layout. Counters are rebuilt from the
/// tracked multiplicities of both inputs instead of taking the larger aggregate
/// counter, which keeps every key removable after the merge. Keys present in
/// both filters in the same slice keep the larger multiplicity; keys in
/// different slices keep both contributions in the slice recorded for the
/// merged key, so later removals never have to search other slices. The
/// insertion counter is recomputed from the merged tracked multiplicities so it
/// stays consistent with the rebuilt counters and serialization.
pub fn ScalableCountingBloomFilter::merge(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Unit {
  self.ensure_same_policy(other)
  // An empty filter contributes no tracked keys and no counters. A count-only
  // filter restored from bytes is also empty in this sense: it carries a
  // conservative insertion count but no tracked key and no positive counter.
  // Rebuilding the receiver from its own metadata would be extra work and could
  // perturb saturated counters, so leave the existing slices untouched. If the
  // empty filter grew further, append the empty slices its layout calls for.
  if other.locations.length() == 0 &&
    (other.inserted == 0 || other.occupied_slot_count() == 0L) {
    let mut total_slots = self.slot_count()
    for i = self.slices.length(); i < other.slices.length(); i = i + 1 {
      total_slots = total_slots + other.slices[i].slot_count().to_int64()
    }
    guard total_slots <= SCALABLE_COUNTING_MAX_SLOTS else {
      abort("scalable counting bloom filter is too large")
    }
    while self.slices.length() < other.slices.length() {
      self.append_slice()
    }
    return
  }
  // The receiver holds no tracked keys and no counters. A count-only receiver
  // restored from bytes is also empty in this sense. Rebuilding every counter
  // from the other filter's metadata would rehash all of its keys, so copy the
  // slices and locations directly. Extra empty slices that the receiver already
  // grew are preserved; their conservative count-only insertion counts are
  // dropped so the merged insertion count stays consistent with its slices.
  let receiver_is_count_only = self.inserted > 0 &&
    self.locations.length() == 0 &&
    self.occupied_slot_count() == 0L
  if (self.inserted == 0 && self.locations.length() == 0) ||
    receiver_is_count_only {
    let self_slice_count = self.slices.length()
    let other_slice_count = other.slices.length()
    let slice_count = if self_slice_count > other_slice_count {
      self_slice_count
    } else {
      other_slice_count
    }
    let mut total_slots = 0L
    for i = 0; i < slice_count; i = i + 1 {
      if i < other_slice_count {
        total_slots = total_slots + other.slices[i].slot_count().to_int64()
      } else {
        total_slots = total_slots + self.slices[i].slot_count().to_int64()
      }
    }
    guard total_slots <= SCALABLE_COUNTING_MAX_SLOTS else {
      abort("scalable counting bloom filter is too large")
    }
    let slices : Array[CountingBloomFilter] = []
    let capacities : Array[Int32] = []
    for i = 0; i < slice_count; i = i + 1 {
      if i < other_slice_count {
        slices.push(other.slices[i].copy())
        capacities.push(other.capacities[i])
      } else {
        let extra = self.slices[i].copy()
        extra.inserted = 0
        slices.push(extra)
        capacities.push(self.capacities[i])
      }
    }
    self.slices = slices
    self.capacities = capacities
    self.locations = other.locations.copy()
    self.inserted = other.inserted
    return
  }
  let self_slice_count = self.slices.length()
  let other_slice_count = other.slices.length()
  let mut total_slots = self.slot_count()
  for i = self_slice_count; i < other_slice_count; i = i + 1 {
    total_slots = total_slots + other.slices[i].slot_count().to_int64()
  }
  guard total_slots <= SCALABLE_COUNTING_MAX_SLOTS else {
    abort("scalable counting bloom filter is too large")
  }
  let slice_count = if self_slice_count > other_slice_count {
    self_slice_count
  } else {
    other_slice_count
  }
  let slices : Array[CountingBloomFilter] = []
  let capacities : Array[Int32] = []
  let slice_inserted : Array[Int64] = Array::make(slice_count, 0L)
  let mut total_inserted = 0L
  for i = 0; i < slice_count; i = i + 1 {
    let source = if i < self_slice_count {
      self.slices[i]
    } else {
      other.slices[i]
    }
    let slice = CountingBloomFilter::with_size(
      source.slot_count(),
      source.hash_count(),
    )
    slices.push(slice)
    if i < self_slice_count {
      capacities.push(self.capacities[i])
    } else {
      capacities.push(other.capacities[i])
    }
  }
  for entry in self.locations.iter() {
    let (id, (slice_index, occurrences)) = entry
    slices[slice_index].raise_positions_for_merge(id.0, id.1, occurrences)
    slice_inserted[slice_index] = slice_inserted[slice_index] +
      occurrences.to_int64()
    total_inserted = total_inserted + occurrences.to_int64()
  }
  let merged = self.locations.copy()
  for entry in other.locations.iter() {
    let (id, (other_slice, other_occurrences)) = entry
    match self.locations.get(id) {
      Some((self_slice, self_occurrences)) =>
        if self_slice == other_slice {
          let occurrences = if self_occurrences > other_occurrences {
            self_occurrences
          } else {
            other_occurrences
          }
          let extra = occurrences - self_occurrences
          slices[other_slice].raise_positions_for_merge(id.0, id.1, extra)
          slice_inserted[other_slice] = slice_inserted[other_slice] +
            extra.to_int64()
          total_inserted = total_inserted + extra.to_int64()
          merged.set(id, (other_slice, occurrences))
        } else {
          guard self_occurrences <= 2147483647 - other_occurrences else {
            abort("scalable counting bloom filter occurrence count overflow")
          }
          slices[self_slice].raise_positions_for_merge(
            id.0,
            id.1,
            other_occurrences,
          )
          slice_inserted[self_slice] = slice_inserted[self_slice] +
            other_occurrences.to_int64()
          total_inserted = total_inserted + other_occurrences.to_int64()
          merged.set(id, (self_slice, self_occurrences + other_occurrences))
        }
      None => {
        slices[other_slice].raise_positions_for_merge(
          id.0,
          id.1,
          other_occurrences,
        )
        slice_inserted[other_slice] = slice_inserted[other_slice] +
          other_occurrences.to_int64()
        total_inserted = total_inserted + other_occurrences.to_int64()
        merged.set(id, (other_slice, other_occurrences))
      }
    }
  }
  guard total_inserted <= 2147483647L else {
    abort("scalable counting bloom filter insertion count overflow")
  }
  for i = 0; i < slice_count; i = i + 1 {
    slices[i].inserted = slice_inserted[i].to_int()
  }
  self.slices = slices
  self.capacities = capacities
  self.locations = merged
  self.inserted = total_inserted.to_int()
}

///|
/// Build a new filter containing every key tracked by either input.
///
/// Both filters must share the same initial capacity and target rate. The
/// result rebuilds counters from the merged tracked multiplicities, so every
/// key tracked by either input remains present and removable. Keys tracked by
/// both filters keep the larger multiplicity when they share a slice and the
/// sum otherwise. The inputs are left unchanged.
pub fn ScalableCountingBloomFilter::union(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> ScalableCountingBloomFilter {
  let result = self.copy()
  result.merge(other)
  result
}

///|
/// Build a new filter containing keys tracked by both inputs.
///
/// Both filters must share the same initial capacity and target rate. A key
/// present in both keeps the smaller multiplicity and is placed in the slice
/// recorded by the shorter input, so keys are found even when the inputs
/// stored them in different slices. The result has as many slices as the
/// shorter input and leaves both inputs unchanged.
pub fn ScalableCountingBloomFilter::intersection(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> ScalableCountingBloomFilter {
  self.ensure_same_policy(other)
  let self_slice_count = self.slices.length()
  let other_slice_count = other.slices.length()
  let slice_count = self_slice_count.min(other_slice_count)
  // A filter can reach this state through whitebox construction with an empty
  // slice list. There is no shared slice layout to intersect, so return a fresh
  // filter with the same growth policy instead of an unusable zero-slice result.
  if slice_count == 0 {
    return ScalableCountingBloomFilter::new(
      self.initial_capacity,
      self.target_rate,
    )
  }
  let mut result_slots = 0L
  for i = 0; i < slice_count; i = i + 1 {
    result_slots = result_slots + self.slices[i].slot_count().to_int64()
  }
  guard result_slots <= SCALABLE_COUNTING_MAX_SLOTS else {
    abort("scalable counting bloom filter is too large")
  }
  let slices : Array[CountingBloomFilter] = []
  let capacities : Array[Int32] = []
  let slice_inserted : Array[Int32] = Array::make(slice_count, 0)
  for i = 0; i < slice_count; i = i + 1 {
    let source = self.slices[i]
    slices.push(
      CountingBloomFilter::with_size(source.slot_count(), source.hash_count()),
    )
    capacities.push(self.capacities[i])
  }
  let locations : @hashmap.HashMap[(UInt64, UInt64), (Int32, Int32)] = @hashmap.HashMap([],
  )
  let scan_self = self.locations.length() <= other.locations.length()
  let scanned = if scan_self { self.locations } else { other.locations }
  let looked_up = if scan_self { other.locations } else { self.locations }
  for entry in scanned.iter() {
    let (id, (scan_slice, scan_occurrences)) = entry
    match looked_up.get(id) {
      Some((lookup_slice, lookup_occurrences)) => {
        let (self_slice, self_occurrences, other_slice, other_occurrences) = if scan_self {
          (scan_slice, scan_occurrences, lookup_slice, lookup_occurrences)
        } else {
          (lookup_slice, lookup_occurrences, scan_slice, scan_occurrences)
        }
        let occurrences = if self_occurrences < other_occurrences {
          self_occurrences
        } else {
          other_occurrences
        }
        let slice_index = if self_slice_count < other_slice_count {
          self_slice
        } else if other_slice_count < self_slice_count {
          other_slice
        } else if self_slice < other_slice {
          self_slice
        } else {
          other_slice
        }
        slices[slice_index].raise_positions_for_merge(id.0, id.1, occurrences)
        slice_inserted[slice_index] = slice_inserted[slice_index] + occurrences
        locations.set(id, (slice_index, occurrences))
      }
      None => ()
    }
  }
  let mut inserted = 0
  for i = 0; i < slice_count; i = i + 1 {
    slices[i].inserted = slice_inserted[i]
    inserted = inserted + slice_inserted[i]
  }
  {
    slices,
    capacities,
    locations,
    initial_capacity: self.initial_capacity,
    target_rate: self.target_rate,
    inserted,
  }
}

///|
/// Whether every key reported present by `self` is also reported present by
/// `other`.
///
/// Both filters must share the same initial capacity and target rate. Counters
/// are first compared slice by slice, which is conservative because slices at
/// different indices use different layouts. When that check fails, the tracked
/// multiplicities decide the result instead: the same key can be stored in
/// different slices by the two inputs, but `locations` still records its exact
/// multiplicity. This makes a union of overlapping filters a subset of itself
/// even when the inputs placed a shared key in different slices.
///
/// The cross-slice fallback is based on tracked keys. Slices at different
/// indices use different hash layouts, so the fallback cannot certify that an
/// untracked false-positive key reported only by `self` is also reported by
/// `other`. Compare filters that grew in lockstep when a strict set-inclusion
/// guarantee is required.
pub fn ScalableCountingBloomFilter::is_subset_of(
  self : ScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Bool {
  self.ensure_same_policy(other)
  let mut counters_are_subset = true
  for i = 0; i < self.slices.length(); i = i + 1 {
    if i < other.slices.length() {
      if !self.slices[i].is_subset_of(other.slices[i]) {
        counters_are_subset = false
        break
      }
    } else if self.slices[i].has_positive_counter() {
      counters_are_subset = false
      break
    }
  }
  if counters_are_subset {
    return true
  }
  // A shared key may have moved to a different slice in the other filter, so
  // compare the tracked multiplicities across slices before reporting a miss.
  // A key that `self` still reports must also be reported by `other`; tracked
  // metadata alone is not enough when the other counters have drained.
  for entry in self.locations.iter() {
    let (id, (_, occurrences)) = entry
    match other.locations.get(id) {
      Some((_, other_occurrences)) =>
        if other_occurrences < occurrences ||
          (self.contains_hashes(id) && !other.contains_hashes(id)) {
          return false
        }
      None => return false
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
  let self_slices = self.slices
  let other_slices = other.slices
  let self_nonempty : Array[Bool] = Array::make(self_slices.length(), false)
  let other_nonempty : Array[Bool] = Array::make(other_slices.length(), false)
  let mut any_self = false
  let mut any_other = false
  for i = 0; i < self_slices.length(); i = i + 1 {
    if self_slices[i].has_positive_counter() {
      self_nonempty[i] = true
      any_self = true
    }
  }
  for i = 0; i < other_slices.length(); i = i + 1 {
    if other_slices[i].has_positive_counter() {
      other_nonempty[i] = true
      any_other = true
    }
  }
  if !any_self || !any_other {
    return true
  }
  for i = 0; i < self_slices.length(); i = i + 1 {
    if !self_nonempty[i] {
      continue
    }
    for j = 0; j < other_slices.length(); j = j + 1 {
      if !other_nonempty[j] {
        continue
      }
      let left = self_slices[i]
      let right = other_slices[j]
      if left.slot_count() != right.slot_count() ||
        left.hash_count() != right.hash_count() {
        return false
      }
      if !left.is_disjoint_from(right) {
        return false
      }
    }
  }
  true
}
