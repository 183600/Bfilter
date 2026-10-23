///|
/// A Bloom filter that grows by adding slices when the current slice reaches
/// its planned capacity.
///
/// Each slice doubles the previous capacity and halves its target
/// false-positive rate, so the combined target rate stays bounded while the
/// filter keeps accepting inserts. Existing keys are never moved between
/// slices, so a key remains reachable in the slice where it was inserted.
pub struct ScalableBloomFilter {
  priv mut slices : Array[BloomFilter]
  priv mut capacities : Array[Int32]
  priv initial_capacity : Int32
  priv target_rate : Double
  priv mut inserted : Int32
}

///|
const SCALABLE_GROWTH : Int32 = 2

///|
fn scalable_slice_rate(target_rate : Double, index : Int32) -> Double {
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
fn ScalableBloomFilter::append_slice(self : ScalableBloomFilter) -> Unit {
  let index = self.slices.length()
  let capacity = if index == 0 {
    self.initial_capacity
  } else {
    let previous = self.capacities[index - 1]
    if previous > 2147483647 / SCALABLE_GROWTH {
      abort("scalable bloom filter is too large")
    }
    previous * SCALABLE_GROWTH
  }
  let (slice_bits, slice_hashes) = bloom_layout(
    capacity,
    scalable_slice_rate(self.target_rate, index),
  )
  let mut bit_count = slice_bits.to_int64()
  for existing in self.slices {
    bit_count = bit_count + existing.bit_count().to_int64()
  }
  guard bit_count <= 2147483584L else {
    abort("scalable bloom filter is too large")
  }
  let slice = BloomFilter::with_size(slice_bits, slice_hashes)
  self.slices.push(slice)
  self.capacities.push(capacity)
}

///|
/// Compute the bit and hash counts of the first slice that
/// `ScalableBloomFilter::new` would create, without allocating it.
///
/// The first slice uses half of the requested false-positive budget; later
/// slices keep halving it, so this helper is only a planning aid for the
/// initial allocation, not for the whole growing filter. Panics for the same
/// invalid arguments as `ScalableBloomFilter::new`.
pub fn ScalableBloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  bloom_layout(expected_items, scalable_slice_rate(false_positive_rate, 0))
}

///|
/// Create a growing Bloom filter sized for an initial `expected_items` keys and
/// the target `false_positive_rate`.
///
/// The first slice starts at the requested capacity; later slices double the
/// capacity and tighten their share of the false-positive budget. Panics if the
/// capacity or rate is invalid or if the filter would exceed the supported
/// storage size.
pub fn ScalableBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ScalableBloomFilter {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  let filter : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: expected_items,
    target_rate: false_positive_rate,
    inserted: 0,
  }
  filter.append_slice()
  filter
}

///|
fn ScalableBloomFilter::ensure_room(self : ScalableBloomFilter) -> Unit {
  // A whitebox-constructed filter can have no slices. There is no newest slice
  // to fill, so create the first one before indexing the slice arrays.
  if self.slices.length() == 0 {
    self.append_slice()
    return
  }
  let last = self.slices.length() - 1
  if self.slices[last].count() >= self.capacities[last] {
    self.append_slice()
  }
}

///|
/// Insert a key whose two hash values have already been computed.
fn ScalableBloomFilter::insert_hashes(
  self : ScalableBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("scalable bloom filter insertion count overflow")
  }
  // A whitebox-constructed filter can carry an insertion count without any
  // slices. Preserve that conservative count in an empty slice before adding
  // the new key, so the filter remains serializable.
  if self.slices.length() == 0 && self.inserted > 0 {
    self.append_slice()
    self.slices[0].inserted = self.inserted
  }
  self.ensure_room()
  self.slices[self.slices.length() - 1].insert_hashes(h1, h2)
  self.inserted += 1
}

///|
/// Insert `key` into the newest slice, adding a slice first when the current
/// one has reached its planned capacity.
pub fn[K : Hash] ScalableBloomFilter::insert(
  self : ScalableBloomFilter,
  key : K,
) -> Unit {
  let (h1, h2) = key_hashes(key)
  self.insert_hashes(h1, h2)
}

///|
/// Insert `key` only when no slice reports it present.
///
/// Returns `true` when the key was inserted. A false positive in any slice can
/// suppress the insertion. The check across slices and the insertion are not
/// atomic; use the concurrent wrapper when other threads may update the filter.
pub fn[K : Hash] ScalableBloomFilter::insert_if_absent(
  self : ScalableBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  if self.contains_hashes(h1, h2) {
    return false
  }
  self.insert_hashes(h1, h2)
  true
}

///|
/// Test a key whose two hash values have already been computed.
fn ScalableBloomFilter::contains_hashes(
  self : ScalableBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  let mut index = self.slices.length() - 1
  while index >= 0 {
    if self.slices[index].contains_hashes(h1, h2) {
      return true
    }
    index = index - 1
  }
  false
}

///|
/// Test whether any slice may contain `key`.
pub fn[K : Hash] ScalableBloomFilter::contains(
  self : ScalableBloomFilter,
  key : K,
) -> Bool {
  // A filter with no outstanding insertions has no set bit in any slice, so a
  // query can answer without hashing the key or walking the slice list. A
  // whitebox-constructed filter can also carry a conservative insertion count
  // without any slices; that state is equally empty.
  if self.inserted == 0 || self.slices.length() == 0 {
    return false
  }
  let (h1, h2) = key_hashes(key)
  self.contains_hashes(h1, h2)
}

///|
/// Insert every key in `keys`, growing the filter as needed.
pub fn[K : Hash] ScalableBloomFilter::insert_all(
  self : ScalableBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  for key in keys {
    self.insert(key)
  }
}

///|
/// Insert every key that is definitely absent and return how many were added.
pub fn[K : Hash] ScalableBloomFilter::insert_all_if_absent(
  self : ScalableBloomFilter,
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
/// Test every key in `keys`, stopping at the first definite miss.
pub fn[K : Hash] ScalableBloomFilter::contains_all(
  self : ScalableBloomFilter,
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
pub fn[K : Hash] ScalableBloomFilter::contains_any(
  self : ScalableBloomFilter,
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
/// Return an independent copy of the filter, including every slice.
pub fn ScalableBloomFilter::copy(
  self : ScalableBloomFilter,
) -> ScalableBloomFilter {
  let slices : Array[BloomFilter] = []
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
    initial_capacity: self.initial_capacity,
    target_rate: self.target_rate,
    inserted: self.inserted,
  }
}

///|
/// Remove every slice and restart from a single empty slice with the original
/// initial capacity and target rate.
pub fn ScalableBloomFilter::clear(self : ScalableBloomFilter) -> Unit {
  self.inserted = 0
  if self.slices.length() == 0 {
    self.capacities = []
    self.append_slice()
    return
  }
  // Reuse the initial slice instead of allocating a new backing array. The
  // first slice always uses the initial capacity and growth policy, so clearing
  // it and dropping every later slice yields the same state as a fresh filter.
  let first = self.slices[0]
  first.clear()
  let slices : Array[BloomFilter] = [first]
  let capacities : Array[Int32] = [self.initial_capacity]
  self.slices = slices
  self.capacities = capacities
}

///|
/// Number of insertions observed since creation or the last `clear`.
pub fn ScalableBloomFilter::count(self : ScalableBloomFilter) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion has happened since creation or the last `clear`.
pub fn ScalableBloomFilter::is_empty(self : ScalableBloomFilter) -> Bool {
  self.inserted == 0
}

///|
/// Number of slices currently backing the filter.
pub fn ScalableBloomFilter::slice_count(self : ScalableBloomFilter) -> Int32 {
  self.slices.length()
}

///|
/// Sum of the planned capacities of the current slices.
pub fn ScalableBloomFilter::capacity(self : ScalableBloomFilter) -> Int64 {
  let mut total = 0L
  for capacity in self.capacities {
    total = total + capacity.to_int64()
  }
  total
}

///|
/// Sum the addressable bit counts of every slice without narrowing to `Int32`.
///
/// A filter built through the public API keeps the aggregate within the
/// supported bit budget, but a hand-built receiver can exceed it. Summing in
/// `Int64` keeps the merge budget guards from wrapping before they can reject
/// such a state.
fn ScalableBloomFilter::total_bits(self : ScalableBloomFilter) -> Int64 {
  let mut total = 0L
  for slice in self.slices {
    total = total + slice.bit_count().to_int64()
  }
  total
}

///|
/// Number of addressable bits across all slices.
pub fn ScalableBloomFilter::bit_count(self : ScalableBloomFilter) -> Int32 {
  let total = self.total_bits()
  guard total <= 2147483584L else {
    abort("scalable bloom filter is too large")
  }
  total.to_int()
}

///|
/// Number of bits currently set to one across all slices.
pub fn ScalableBloomFilter::set_bit_count(self : ScalableBloomFilter) -> Int32 {
  let mut total = 0
  for slice in self.slices {
    total = total + slice.set_bit_count()
  }
  total
}

///|
/// Fraction of addressable bits currently set to one, in `[0, 1]`.
///
/// A hand-built filter with no slices has no addressable bits, so the ratio is
/// `0` rather than `0 / 0`.
pub fn ScalableBloomFilter::fill_ratio(self : ScalableBloomFilter) -> Double {
  let bits = self.bit_count()
  if bits == 0 {
    0.0
  } else {
    self.set_bit_count().to_double() / bits.to_double()
  }
}

///|
/// Estimate the number of distinct keys represented by the current set bits.
///
/// The per-slice estimates are summed, which is conservative when a key could
/// be reported by more than one slice through false positives.
pub fn ScalableBloomFilter::estimated_item_count(
  self : ScalableBloomFilter,
) -> Double {
  let mut total = 0.0
  for slice in self.slices {
    total = total + slice.estimated_item_count()
  }
  total
}

///|
/// Target false-positive rate requested at construction time.
pub fn ScalableBloomFilter::target_false_positive_rate(
  self : ScalableBloomFilter,
) -> Double {
  self.target_rate
}

///|
/// Estimated current false-positive rate across all slices.
///
/// The rate is `1 - product(1 - p_i)` over the per-slice estimates, so it stays
/// zero for an empty filter and approaches one as the slices fill.
pub fn ScalableBloomFilter::false_positive_rate(
  self : ScalableBloomFilter,
) -> Double {
  let mut miss_rate = 1.0
  for slice in self.slices {
    miss_rate = miss_rate * (1.0 - slice.false_positive_rate())
  }
  1.0 - miss_rate
}

///|
/// Number of bytes occupied by the bit arrays of all slices.
pub fn ScalableBloomFilter::memory_bytes(self : ScalableBloomFilter) -> Int64 {
  let mut total = 0L
  for slice in self.slices {
    total = total + slice.memory_bytes()
  }
  total
}

///|
fn ScalableBloomFilter::ensure_same_policy(
  self : ScalableBloomFilter,
  other : ScalableBloomFilter,
) -> Unit {
  guard self.initial_capacity == other.initial_capacity &&
    self.target_rate == other.target_rate else {
    abort(
      "scalable bloom filters must share the initial capacity and target rate",
    )
  }
}

///|
/// Merge every slice of `other` into `self` in place.
///
/// Both filters must share the same initial capacity and target rate, so slice
/// `i` of each filter uses the same layout and their bits are combined with a
/// bitwise OR. Slices that only `other` holds are appended as copies. After
/// merging, `self` reports every key reported by either input. The insertion
/// counter becomes the sum of the input counts, a conservative upper bound when
/// keys overlap, and a slice whose combined count exceeds its planned capacity
/// triggers growth before the next insertion.
pub fn ScalableBloomFilter::merge(
  self : ScalableBloomFilter,
  other : ScalableBloomFilter,
) -> Unit {
  self.ensure_same_policy(other)
  // A whitebox-constructed filter can have no slices. Merging two such filters
  // would otherwise leave the receiver in a transient zero-slice state that
  // cannot be serialized, so normalize it to one empty initial slice carrying
  // the combined conservative insertion count.
  if self.slices.length() == 0 && other.slices.length() == 0 {
    let total = self.inserted.to_int64() + other.inserted.to_int64()
    guard total >= 0L && total <= 2147483647L else {
      abort("scalable bloom filter insertion count overflow")
    }
    self.append_slice()
    self.slices[0].inserted = total.to_int()
    self.inserted = total.to_int()
    return
  }
  // The receiver can also carry a conservative count without any slices even
  // when the source has slices. Preserve it in an empty slice before merging.
  if self.slices.length() == 0 && self.inserted > 0 {
    self.append_slice()
    self.slices[0].inserted = self.inserted
  }
  // Merging an empty filter whose slices are already covered by the receiver
  // cannot change any bit or append a slice. Skip the per-slice OR scans.
  if other.inserted == 0 && other.slices.length() <= self.slices.length() {
    return
  }
  // The receiver holds no bits, so ORing every slice would only copy the other
  // filter into empty storage. Copy the slices directly instead, keeping any
  // extra empty slices the receiver already grew.
  if self.inserted == 0 {
    let self_slice_count = self.slices.length()
    let other_slice_count = other.slices.length()
    let slice_count = if self_slice_count > other_slice_count {
      self_slice_count
    } else {
      other_slice_count
    }
    let mut total_bits = 0L
    for i = 0; i < slice_count; i = i + 1 {
      if i < other_slice_count {
        total_bits = total_bits + other.slices[i].bit_count().to_int64()
      } else {
        total_bits = total_bits + self.slices[i].bit_count().to_int64()
      }
    }
    guard total_bits <= 2147483584L else {
      abort("scalable bloom filter is too large")
    }
    let slices : Array[BloomFilter] = []
    let capacities : Array[Int32] = []
    for i = 0; i < slice_count; i = i + 1 {
      if i < other_slice_count {
        slices.push(other.slices[i].copy())
        capacities.push(other.capacities[i])
      } else {
        slices.push(self.slices[i].copy())
        capacities.push(self.capacities[i])
      }
    }
    self.slices = slices
    self.capacities = capacities
    if other_slice_count == 0 && other.inserted > 0 {
      let total = self.slices[0].inserted.to_int64() + other.inserted.to_int64()
      guard total <= 2147483647L else {
        abort("scalable bloom filter insertion count overflow")
      }
      self.slices[0].inserted = total.to_int()
    }
    self.inserted = other.inserted
    return
  }
  guard self.inserted <= 2147483647 - other.inserted else {
    abort("scalable bloom filter insertion count overflow")
  }
  let mut total_bits = self.total_bits()
  for i = self.slices.length(); i < other.slices.length(); i = i + 1 {
    total_bits = total_bits + other.slices[i].bit_count().to_int64()
  }
  guard total_bits <= 2147483584L else {
    abort("scalable bloom filter is too large")
  }
  // A source with no slices but a conservative count still contributes that
  // count to the merged filter, so record it in the receiver's first slice.
  if other.slices.length() == 0 && other.inserted > 0 {
    let total = self.slices[0].inserted.to_int64() + other.inserted.to_int64()
    guard total <= 2147483647L else {
      abort("scalable bloom filter insertion count overflow")
    }
    self.slices[0].inserted = total.to_int()
  }
  for i = 0; i < other.slices.length(); i = i + 1 {
    if i < self.slices.length() {
      self.slices[i].merge(other.slices[i])
    } else {
      self.slices.push(other.slices[i].copy())
      self.capacities.push(other.capacities[i])
    }
  }
  self.inserted += other.inserted
}

///|
/// Build a new filter containing every key present in either input.
///
/// Both filters must share the same initial capacity and target rate. The
/// result uses the per-slice union of their bit arrays, so it never reports a
/// false negative for a key either input reported present. The inputs are left
/// unchanged.
pub fn ScalableBloomFilter::union(
  self : ScalableBloomFilter,
  other : ScalableBloomFilter,
) -> ScalableBloomFilter {
  let result = self.copy()
  result.merge(other)
  result
}

///|
/// Build a new filter containing keys reported present by both inputs.
///
/// Both filters must share the same initial capacity and target rate. Slice `i`
/// of `self` is intersected with slice `i` of `other`, and slices beyond the
/// shorter filter are omitted because they have no counterpart to compare. The
/// insertion count is the smaller of the input counts, matching classic Bloom
/// filter intersection. The inputs are left unchanged.
pub fn ScalableBloomFilter::intersection(
  self : ScalableBloomFilter,
  other : ScalableBloomFilter,
) -> ScalableBloomFilter {
  self.ensure_same_policy(other)
  let slice_count = self.slices.length().min(other.slices.length())
  // A filter can reach this state through whitebox construction with an empty
  // slice list. There is no shared slice layout to intersect, so start from a
  // fresh filter with the same growth policy. Its conservative insertion count
  // is still the smaller of the input counts, matching every other layout.
  if slice_count == 0 {
    let result = ScalableBloomFilter::new(
      self.initial_capacity,
      self.target_rate,
    )
    let inserted = self.inserted.min(other.inserted)
    if inserted > 0 {
      result.slices[0].inserted = inserted
      result.inserted = inserted
    }
    return result
  }
  let mut result_bits = 0L
  for i = 0; i < slice_count; i = i + 1 {
    result_bits = result_bits + self.slices[i].bit_count().to_int64()
  }
  guard result_bits <= 2147483584L else {
    abort("scalable bloom filter is too large")
  }
  let slices : Array[BloomFilter] = []
  let capacities : Array[Int32] = []
  let mut slice_total = 0L
  for i = 0; i < slice_count; i = i + 1 {
    let slice = self.slices[i].intersection(other.slices[i])
    slice_total = slice_total + slice.count().to_int64()
    slices.push(slice)
    capacities.push(self.capacities[i])
  }
  guard slice_total <= 2147483647L else {
    abort("scalable bloom filter insertion count overflow")
  }
  let slice_total = slice_total.to_int()
  let inserted = self.inserted.min(other.inserted)
  if slice_total < inserted {
    slices[0].inserted = slices[0].inserted + (inserted - slice_total)
  }
  let mut total_bits = 0L
  for slice in slices {
    total_bits = total_bits + slice.bit_count().to_int64()
  }
  guard total_bits <= 2147483584L else {
    abort("scalable bloom filter is too large")
  }
  {
    slices,
    capacities,
    initial_capacity: self.initial_capacity,
    target_rate: self.target_rate,
    inserted,
  }
}

///|
/// Whether every key reported present by `self` is also reported present by
/// `other`.
///
/// Both filters must share the same initial capacity and target rate. Slice `i`
/// of `self` is compared only against slice `i` of `other` because slices with
/// different indices use different layouts; a slice of `self` beyond the last
/// slice of `other` must be completely empty. A `true` result is therefore
/// sufficient but not necessary for membership containment: a key missed by its
/// own slice in `other` could still be covered by another slice.
pub fn ScalableBloomFilter::is_subset_of(
  self : ScalableBloomFilter,
  other : ScalableBloomFilter,
) -> Bool {
  self.ensure_same_policy(other)
  // An empty filter has no set bit in any slice, so it is a subset of every
  // filter. This avoids scanning the backing words of every slice just to
  // discover that they are empty.
  if self.inserted == 0 {
    return true
  }
  for i = 0; i < self.slices.length(); i = i + 1 {
    if i < other.slices.length() {
      if !self.slices[i].is_subset_of(other.slices[i]) {
        return false
      }
    } else if self.slices[i].has_set_bit() {
      return false
    }
  }
  true
}

///|
/// Whether `self` and `other` are definitely disjoint.
///
/// Both filters must share the same initial capacity and target rate. Returns
/// `true` only when every slice of `self` has no bit set in common with every
/// slice of `other`. A key can only be reported by both filters when its bits
/// are set in one slice of each, so this guarantees no key is reported present
/// by both. A `false` result is inconclusive because equal bits may come from
/// different keys.
///
/// Slices at different indices use different layouts, so their bit arrays
/// cannot be compared directly. A pair of slices with different layouts is
/// treated as not provably disjoint once both are non-empty; an empty slice
/// never reports any key and therefore cannot overlap.
pub fn ScalableBloomFilter::is_disjoint_from(
  self : ScalableBloomFilter,
  other : ScalableBloomFilter,
) -> Bool {
  self.ensure_same_policy(other)
  // An empty filter has no set bit in any slice, so no key can be reported by
  // both inputs. Skip the per-slice occupancy scans in that case.
  if self.inserted == 0 || other.inserted == 0 {
    return true
  }
  let self_slices = self.slices
  let other_slices = other.slices
  let self_nonempty : Array[Bool] = Array::make(self_slices.length(), false)
  let other_nonempty : Array[Bool] = Array::make(other_slices.length(), false)
  let mut any_self = false
  let mut any_other = false
  for i = 0; i < self_slices.length(); i = i + 1 {
    if self_slices[i].has_set_bit() {
      self_nonempty[i] = true
      any_self = true
    }
  }
  for i = 0; i < other_slices.length(); i = i + 1 {
    if other_slices[i].has_set_bit() {
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
      if left.bit_count() != right.bit_count() ||
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
