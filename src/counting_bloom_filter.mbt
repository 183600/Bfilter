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
  priv mut counter_mass : UInt64
}

///|
/// Compute the slot and hash layout used by counting filters.
fn counting_bloom_layout(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  let n = expected_items.to_double()
  let ln2 = 0.6931471805599453
  let bits = -(n * @math.ln(false_positive_rate)) / (ln2 * ln2)
  guard bits <= 2147483584.0 else { abort("bloom filter size is too large") }
  let slot_count = (bits.ceil().to_int() + 15) / 16 * 16
  guard slot_count <= 1073741808 else {
    abort("counting bloom filter size is too large")
  }
  let hash_count = (bits / n * ln2).round().to_int().max(1)
  (slot_count, hash_count)
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
  let (slot_count, hash_count) = counting_bloom_layout(
    expected_items, false_positive_rate,
  )
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
    counter_mass: 0UL,
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
  self.counter_mass = self.counter_mass - old + value
}

///|
/// Compute each distinct slot selected by a key together with the number of
/// hash functions that select it.
///
/// Small filters accumulate counts in a compact array with a quadratic scan;
/// filters with many hash functions switch to a hash map so duplicate detection
/// stays linear instead of rescanning every previously seen position.
fn unique_key_positions(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : UInt64,
) -> Array[(Int32, Int32)] {
  let unique : Array[(Int32, Int32)] = []
  let mut state = h1
  if hash_count <= 64 {
    let positions : Array[Int32] = Array::make(hash_count, 0)
    for i = 0; i < hash_count; i = i + 1 {
      positions[i] = (state % slot_count).to_int()
      state = state + h2
    }
    for i = 0; i < hash_count; i = i + 1 {
      let position = positions[i]
      let mut found = false
      for j = 0; j < unique.length(); j = j + 1 {
        if unique[j].0 == position {
          unique[j] = (position, unique[j].1 + 1)
          found = true
          break
        }
      }
      if !found {
        unique.push((position, 1))
      }
    }
  } else {
    let counts : @hashmap.HashMap[Int32, Int32] = @hashmap.HashMap([])
    for i = 0; i < hash_count; i = i + 1 {
      let position = (state % slot_count).to_int()
      match counts.get(position) {
        Some(occurrences) => counts.set(position, occurrences + 1)
        None => counts.set(position, 1)
      }
      state = state + h2
    }
    for entry in counts.iter() {
      unique.push(entry)
    }
  }
  unique
}

///|
/// Raise every selected counter by the number of hash functions that select
/// it, capping at the largest multiple of that count that fits in 16 bits.
///
/// Capping below 65535 when a position repeats keeps the counter removable:
/// each removal subtracts exactly the same amount that each insertion added,
/// so a saturated key eventually reaches zero instead of stranding a residue.
fn CountingBloomFilter::raise_positions(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
  multiplicity : Int32,
) -> Unit {
  let slot_count = self.slot_count.to_uint64()
  let positions = unique_key_positions(h1, h2, self.hash_count, slot_count)
  for entry in positions {
    let (pos, occurrences) = entry
    let occurrences = occurrences.to_uint64()
    let limit = if occurrences > 65535UL {
      65535UL
    } else {
      65535UL - 65535UL % occurrences
    }
    let value = self.counter_at(pos)
    if value < limit {
      let added = multiplicity.to_uint64() * occurrences
      let raised = value + added
      self.set_counter(pos, if raised > limit { limit } else { raised })
    }
  }
}

///|
fn CountingBloomFilter::increment_positions(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Unit {
  self.raise_positions(h1, h2, 1)
}

///|
/// Insert a key whose two hash values have already been computed.
fn CountingBloomFilter::insert_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("counting bloom filter insertion count overflow")
  }
  self.increment_positions(h1, h2)
  self.inserted += 1
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
  let (h1, h2) = key_hashes(key)
  self.insert_hashes(h1, h2)
}

///|
/// Insert a key with precomputed hashes when at least one counter is zero.
fn CountingBloomFilter::insert_if_absent_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  let slot_count = self.slot_count.to_uint64()
  let mut state = h1
  for i = 0; i < self.hash_count; i = i + 1 {
    if self.counter_at((state % slot_count).to_int()) == 0UL {
      guard self.inserted < 2147483647 else {
        abort("counting bloom filter insertion count overflow")
      }
      self.increment_positions(h1, h2)
      self.inserted += 1
      return true
    }
    state = state + h2
  }
  false
}

///|
/// Insert `key` only when at least one selected counter is zero.
///
/// Returns `true` when the key was inserted, or `false` when every selected
/// counter was positive and the key may already be present. False positives
/// can therefore suppress an insertion that would otherwise be harmless.
pub fn[K : Hash] CountingBloomFilter::insert_if_absent(
  self : CountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  self.insert_if_absent_hashes(h1, h2)
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
  self.remove_hashes(h1, h2)
}

///|
fn CountingBloomFilter::remove_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  let slot_count = self.slot_count.to_uint64()
  let positions = unique_key_positions(h1, h2, self.hash_count, slot_count)
  for entry in positions {
    let (pos, occurrences) = entry
    let required = if occurrences.to_uint64() > 0xFFFFUL {
      0xFFFFUL
    } else {
      occurrences.to_uint64()
    }
    if self.counter_at(pos) < required {
      return false
    }
  }
  for entry in positions {
    let (pos, occurrences) = entry
    let occurrences = occurrences.to_uint64()
    let value = self.counter_at(pos)
    let decrement = if value < occurrences { value } else { occurrences }
    self.set_counter(pos, value - decrement)
  }
  let needed = (self.counter_mass + self.hash_count.to_uint64() - 1UL) /
    self.hash_count.to_uint64()
  let mut next = if self.inserted > 0 { self.inserted - 1 } else { 0 }
  if needed > next.to_uint64() {
    next = needed.to_int()
  }
  self.inserted = next
  true
}

///|
/// Test a key whose two hash values have already been computed.
fn CountingBloomFilter::contains_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  let slot_count = self.slot_count.to_uint64()
  let mut state = h1
  for i = 0; i < self.hash_count; i = i + 1 {
    if self.counter_at((state % slot_count).to_int()) == 0UL {
      return false
    }
    state = state + h2
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
  self.contains_hashes(h1, h2)
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
  let mut state = h1
  let mut minimum = 65535UL
  for i = 0; i < self.hash_count; i = i + 1 {
    let value = self.counter_at((state % slot_count).to_int())
    if value < minimum {
      minimum = value
    }
    state = state + h2
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
/// Insert every key that is definitely absent and return how many were added.
///
/// Duplicate keys within `keys` and keys already represented by positive
/// counters are skipped. An empty view returns `0`.
pub fn[K : Hash] CountingBloomFilter::insert_all_if_absent(
  self : CountingBloomFilter,
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
  let mut merged_mass = 0UL
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    let mut merged = 0UL
    for lane = 0; lane < 4; lane = lane + 1 {
      let shift = lane * 16
      let a = (left >> shift) & 0xFFFFUL
      let b = (right >> shift) & 0xFFFFUL
      let value = if a > b { a } else { b }
      merged = merged | (value << shift)
      merged_mass = merged_mass + value
    }
    self.counters[i] = merged
  }
  self.counter_mass = merged_mass
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
  let mut merged_mass = 0UL
  for i = 0; i < result.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    let mut merged = 0UL
    for lane = 0; lane < 4; lane = lane + 1 {
      let shift = lane * 16
      let a = (left >> shift) & 0xFFFFUL
      let b = (right >> shift) & 0xFFFFUL
      let value = if a < b { a } else { b }
      merged = merged | (value << shift)
      merged_mass = merged_mass + value
    }
    result.counters[i] = merged
  }
  result.counter_mass = merged_mass
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
/// Whether `self` and `other` are definitely disjoint.
///
/// Both filters must use the same slot and hash counts. Returns `true` only
/// when no slot has a positive counter in both filters, which guarantees that
/// no key can be reported present by both. A `false` result is inconclusive
/// because a slot may be positive for different keys.
pub fn CountingBloomFilter::is_disjoint_from(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    for lane = 0; lane < 4; lane = lane + 1 {
      let shift = lane * 16
      if ((left >> shift) & 0xFFFFUL) != 0UL &&
        ((right >> shift) & 0xFFFFUL) != 0UL {
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
    counter_mass: self.counter_mass,
  }
}

///|
/// Reset every counter and the insertion counter.
pub fn CountingBloomFilter::clear(self : CountingBloomFilter) -> Unit {
  for i = 0; i < self.counters.length(); i = i + 1 {
    self.counters[i] = 0UL
  }
  self.inserted = 0
  self.counter_mass = 0UL
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
