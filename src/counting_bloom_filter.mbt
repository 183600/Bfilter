///|
/// A Bloom filter variant that stores a counter per slot, enabling deletion.
///
/// Counters are packed four per `UInt64` as 16-bit values, so each slot costs
/// two bytes. A counter saturates at 65535 instead of wrapping; removing a key
/// that was never inserted can still corrupt the filter when it produces a
/// false positive, which is inherent to counting Bloom filters.
pub struct CountingBloomFilter {
  priv counters : FixedArray[UInt64]
  priv slot_count : Int32
  priv hash_count : Int32
  priv mut inserted : Int32
}

///|
/// Create a counting filter sized for `expected_items` and the target
/// `false_positive_rate`.
///
/// Panics if `expected_items` is not positive, the rate is not in `(0, 1)`, or
/// the requested filter would exceed the supported size.
pub fn CountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> CountingBloomFilter {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  let n = expected_items.to_double()
  let ln2 = 0.6931471805599453
  let bits = -(n * @math.ln(false_positive_rate)) / (ln2 * ln2)
  guard bits <= 2147483584.0 else { abort("bloom filter size is too large") }
  let slot_count = (bits.ceil().to_int() + 63) / 64 * 64
  let hash_count = (bits / n * ln2).round().to_int().max(1)
  CountingBloomFilter::with_size(slot_count, hash_count)
}

///|
/// Create a counting filter with an explicit slot and hash count.
///
/// `slot_count` is rounded up to a multiple of 16 so counters pack evenly into
/// `UInt64` words.
pub fn CountingBloomFilter::with_size(
  slot_count : Int32,
  hash_count : Int32,
) -> CountingBloomFilter {
  guard slot_count > 0 && slot_count <= 1073741808 else {
    abort("slot_count must be positive and not too large")
  }
  guard hash_count > 0 else { abort("hash_count must be positive") }
  let rounded = (slot_count + 15) / 16 * 16
  {
    counters: FixedArray::make(rounded / 4, 0UL),
    slot_count: rounded,
    hash_count,
    inserted: 0,
  }
}

///|
fn CountingBloomFilter::counter_at(
  self : CountingBloomFilter,
  position : Int32,
) -> UInt64 {
  let word = position / 4
  let shift = position % 4 * 16
  (self.counters[word] >> shift) & 0xFFFFUL
}

///|
fn CountingBloomFilter::set_counter(
  self : CountingBloomFilter,
  position : Int32,
  value : UInt64,
) -> Unit {
  let word = position / 4
  let shift = position % 4 * 16
  let value = if value > 0xFFFFUL { 0xFFFFUL } else { value }
  let old = (self.counters[word] >> shift) & 0xFFFFUL
  let cleared = self.counters[word] ^ (old << shift)
  self.counters[word] = cleared | (value << shift)
}

///|
/// Insert `key` by incrementing every selected counter.
///
/// Counters at 65535 stay saturated. The insertion counter is incremented for
/// every call, including duplicate keys.
pub fn[K : Hash] CountingBloomFilter::insert(
  self : CountingBloomFilter,
  key : K,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("counting bloom filter insertion count overflow")
  }
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, slot_count)
    let value = self.counter_at(pos)
    if value < 65535UL {
      self.set_counter(pos, value + 1UL)
    }
  }
  self.inserted += 1
}

///|
/// Remove one insertion of `key` by decrementing every selected counter.
///
/// Returns `true` when all counters were positive and were decremented. A key
/// that was never inserted may still return `true` on a false positive and
/// remove another key's contribution; only remove keys known to be present.
pub fn[K : Hash] CountingBloomFilter::remove(
  self : CountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, slot_count)
    if self.counter_at(pos) == 0UL {
      return false
    }
  }
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, slot_count)
    let value = self.counter_at(pos)
    if value == 0UL {
      for j = 0; j < i; j = j + 1 {
        let previous = bit_index(h1, h2, j, slot_count)
        self.set_counter(previous, self.counter_at(previous) + 1UL)
      }
      return false
    }
    self.set_counter(pos, value - 1UL)
  }
  if self.inserted > 0 {
    self.inserted -= 1
  }
  true
}

///|
/// Test whether every counter selected by `key` is positive.
pub fn[K : Hash] CountingBloomFilter::contains(
  self : CountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, slot_count)
    if self.counter_at(pos) == 0UL {
      return false
    }
  }
  true
}

///|
/// Estimate how many insertions of `key` the filter currently represents.
///
/// The result is the smallest counter selected by `key`. It can exceed the
/// true multiplicity when other keys share those slots, and it is never lower
/// than the number of insertions unless a counter has saturated. A key that
/// hashes to a slot with a zero counter is reported as `0`.
pub fn[K : Hash] CountingBloomFilter::count_of(
  self : CountingBloomFilter,
  key : K,
) -> Int32 {
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  let mut minimum = 65535UL
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, slot_count)
    let value = self.counter_at(pos)
    if value < minimum {
      minimum = value
    }
  }
  minimum.to_int()
}

///|
/// Insert every key in `keys`. An empty view is a no-op.
pub fn[K : Hash] CountingBloomFilter::insert_all(
  self : CountingBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  for key in keys {
    self.insert(key)
  }
}

///|
/// Remove one insertion of every key in `keys`.
///
/// Continues after a key cannot be removed and returns `true` only when every
/// removal succeeded. An empty view returns `true`.
pub fn[K : Hash] CountingBloomFilter::remove_all(
  self : CountingBloomFilter,
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
fn CountingBloomFilter::ensure_compatible(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Unit {
  guard self.slot_count == other.slot_count &&
    self.hash_count == other.hash_count else {
    abort("counting bloom filters must have the same slot and hash counts")
  }
}

///|
/// Merge every counter of `other` into `self` in place.
///
/// Both filters must use the same slot and hash counts. Each counter becomes
/// the larger of the two values, so all keys from both filters remain present
/// and a key inserted multiple times keeps the larger multiplicity. The
/// insertion counter becomes the sum of the input counts, a conservative upper
/// bound because keys overlap.
pub fn CountingBloomFilter::merge(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Unit {
  self.ensure_compatible(other)
  guard self.inserted <= 2147483647 - other.inserted else {
    abort("counting bloom filter insertion count overflow")
  }
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    let mut merged = 0UL
    for lane = 0; lane < 4; lane = lane + 1 {
      let shift = lane * 16
      let a = (left >> shift) & 0xFFFFUL
      let b = (right >> shift) & 0xFFFFUL
      merged = merged | ((if a > b { a } else { b }) << shift)
    }
    self.counters[i] = merged
  }
  self.inserted += other.inserted
}

///|
/// Build a new filter that reports every key present in either input.
///
/// Both filters must use the same slot and hash counts. Each counter is the
/// larger of the two input counters, so all keys from both filters remain
/// present and a key inserted multiple times keeps the larger multiplicity.
/// The insertion count is the sum of the input counts, a conservative upper
/// bound because keys may overlap.
pub fn CountingBloomFilter::union(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> CountingBloomFilter {
  let result = self.copy()
  result.merge(other)
  result
}

///|
/// Build a new filter that reports every key present in both inputs.
///
/// Both filters must use the same slot and hash counts. Each counter is the
/// smaller of the two input counters, so keys present in both remain present
/// while slots occupied by only one input are cleared. The insertion count is
/// the smaller of the input counts, a conservative upper bound.
pub fn CountingBloomFilter::intersection(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> CountingBloomFilter {
  self.ensure_compatible(other)
  let result = CountingBloomFilter::with_size(self.slot_count, self.hash_count)
  for i = 0; i < result.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    let mut merged = 0UL
    for lane = 0; lane < 4; lane = lane + 1 {
      let shift = lane * 16
      let a = (left >> shift) & 0xFFFFUL
      let b = (right >> shift) & 0xFFFFUL
      merged = merged | ((if a < b { a } else { b }) << shift)
    }
    result.counters[i] = merged
  }
  result.inserted = self.inserted.min(other.inserted)
  result
}

///|
/// Whether every counter in `self` is less than or equal to the corresponding
/// counter in `other`.
///
/// Both filters must use the same slot and hash counts. A `true` result means
/// every key and insertion multiplicity reported by `self` is also represented
/// by `other`, including keys that share slots through hash collisions.
pub fn CountingBloomFilter::is_subset_of(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    for lane = 0; lane < 4; lane = lane + 1 {
      let shift = lane * 16
      if ((left >> shift) & 0xFFFFUL) > ((right >> shift) & 0xFFFFUL) {
        return false
      }
    }
  }
  true
}

///|
/// Test every key in `keys`, returning `false` at the first definite miss.
pub fn[K : Hash] CountingBloomFilter::contains_all(
  self : CountingBloomFilter,
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
///
/// Returns `false` for an empty view.
pub fn[K : Hash] CountingBloomFilter::contains_any(
  self : CountingBloomFilter,
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
/// Return an independent copy of the filter.
///
/// Later inserts or removals on either filter do not affect the other.
pub fn CountingBloomFilter::copy(
  self : CountingBloomFilter,
) -> CountingBloomFilter {
  {
    counters: self.counters.copy(),
    slot_count: self.slot_count,
    hash_count: self.hash_count,
    inserted: self.inserted,
  }
}

///|
/// Reset every counter and the insertion counter.
pub fn CountingBloomFilter::clear(self : CountingBloomFilter) -> Unit {
  for i = 0; i < self.counters.length(); i = i + 1 {
    self.counters[i] = 0UL
  }
  self.inserted = 0
}

///|
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn CountingBloomFilter::count(self : CountingBloomFilter) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion is currently outstanding.
pub fn CountingBloomFilter::is_empty(self : CountingBloomFilter) -> Bool {
  self.inserted == 0
}

///|
/// Number of addressable counters, always a multiple of 16.
pub fn CountingBloomFilter::slot_count(self : CountingBloomFilter) -> Int32 {
  self.slot_count
}

///|
/// Number of counters updated per operation.
pub fn CountingBloomFilter::hash_count(self : CountingBloomFilter) -> Int32 {
  self.hash_count
}

///|
/// Number of slots with a positive counter.
pub fn CountingBloomFilter::occupied_slot_count(
  self : CountingBloomFilter,
) -> Int32 {
  let mut total = 0
  for i = 0; i < self.counters.length(); i = i + 1 {
    let word = self.counters[i]
    for lane = 0; lane < 4; lane = lane + 1 {
      if ((word >> (lane * 16)) & 0xFFFFUL) != 0UL {
        total = total + 1
      }
    }
  }
  total
}

///|
/// Fraction of slots with a positive counter, in `[0, 1]`.
pub fn CountingBloomFilter::fill_ratio(self : CountingBloomFilter) -> Double {
  self.occupied_slot_count().to_double() / self.slot_count.to_double()
}

///|
/// Estimate the number of distinct keys represented by the occupied slots.
///
/// Uses the same occupancy formula as `BloomFilter::estimated_item_count`, with
/// the slot count in place of the bit count.
pub fn CountingBloomFilter::estimated_item_count(
  self : CountingBloomFilter,
) -> Double {
  let m = self.slot_count.to_double()
  let x = self.occupied_slot_count().to_double()
  if x == 0.0 {
    0.0
  } else if x >= m {
    @double.infinity
  } else {
    -(m / self.hash_count.to_double()) * @math.ln(1.0 - x / m)
  }
}

///|
/// Number of bytes occupied by the packed counters.
pub fn CountingBloomFilter::memory_bytes(self : CountingBloomFilter) -> Int64 {
  self.counters.length().to_int64() * 8L
}

///|
/// Estimated false-positive rate for the current insertion count.
///
/// Uses the same formula as `BloomFilter::false_positive_rate`, with the slot
/// count in place of the bit count.
pub fn CountingBloomFilter::false_positive_rate(
  self : CountingBloomFilter,
) -> Double {
  if self.inserted == 0 {
    0.0
  } else {
    let n = self.inserted.to_double()
    let k = self.hash_count.to_double()
    let m = self.slot_count.to_double()
    @math.pow(1.0 - @math.exp(-k * n / m), k)
  }
}
