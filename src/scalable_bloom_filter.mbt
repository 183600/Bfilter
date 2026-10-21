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
    target_rate
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
  let slice = BloomFilter::new(
    capacity,
    scalable_slice_rate(self.target_rate, index),
  )
  let mut bit_count = slice.bit_count().to_int64()
  for existing in self.slices {
    bit_count = bit_count + existing.bit_count().to_int64()
  }
  guard bit_count <= 2147483584L else {
    abort("scalable bloom filter is too large")
  }
  self.slices.push(slice)
  self.capacities.push(capacity)
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
  let last = self.slices.length() - 1
  if self.slices[last].count() >= self.capacities[last] {
    self.append_slice()
  }
}

///|
/// Insert `key` into the newest slice, adding a slice first when the current
/// one has reached its planned capacity.
pub fn[K : Hash] ScalableBloomFilter::insert(
  self : ScalableBloomFilter,
  key : K,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("scalable bloom filter insertion count overflow")
  }
  self.ensure_room()
  self.slices[self.slices.length() - 1].insert(key)
  self.inserted += 1
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
  if self.contains(key) {
    return false
  }
  guard self.inserted < 2147483647 else {
    abort("scalable bloom filter insertion count overflow")
  }
  self.ensure_room()
  self.slices[self.slices.length() - 1].insert(key)
  self.inserted += 1
  true
}

///|
/// Test whether any slice may contain `key`.
pub fn[K : Hash] ScalableBloomFilter::contains(
  self : ScalableBloomFilter,
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
  self.slices = []
  self.capacities = []
  self.inserted = 0
  self.append_slice()
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
/// Number of addressable bits across all slices.
pub fn ScalableBloomFilter::bit_count(self : ScalableBloomFilter) -> Int32 {
  let mut total = 0
  for slice in self.slices {
    total = total + slice.bit_count()
  }
  total
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
pub fn ScalableBloomFilter::fill_ratio(self : ScalableBloomFilter) -> Double {
  self.set_bit_count().to_double() / self.bit_count().to_double()
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
  guard self.inserted <= 2147483647 - other.inserted else {
    abort("scalable bloom filter insertion count overflow")
  }
  let mut total_bits = self.bit_count().to_int64()
  for i = self.slices.length(); i < other.slices.length(); i = i + 1 {
    total_bits = total_bits + other.slices[i].bit_count().to_int64()
  }
  guard total_bits <= 2147483584L else {
    abort("scalable bloom filter is too large")
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
/// shorter filter are omitted because they have no counterpart to compare.
/// The inputs are left unchanged.
pub fn ScalableBloomFilter::intersection(
  self : ScalableBloomFilter,
  other : ScalableBloomFilter,
) -> ScalableBloomFilter {
  self.ensure_same_policy(other)
  let slice_count = self.slices.length().min(other.slices.length())
  let slices : Array[BloomFilter] = []
  let capacities : Array[Int32] = []
  let mut inserted = 0
  for i = 0; i < slice_count; i = i + 1 {
    let slice = self.slices[i].intersection(other.slices[i])
    inserted = inserted + slice.count()
    slices.push(slice)
    capacities.push(self.capacities[i])
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
  for i = 0; i < self.slices.length(); i = i + 1 {
    if i < other.slices.length() {
      if !self.slices[i].is_subset_of(other.slices[i]) {
        return false
      }
    } else if self.slices[i].set_bit_count() > 0 {
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
  for left in self.slices {
    for right in other.slices {
      if left.set_bit_count() > 0 && right.set_bit_count() > 0 {
        if left.bit_count() != right.bit_count() ||
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
