///|
/// A counting Bloom filter that packs each counter into a single nibble.
///
/// Counters are packed sixteen per `UInt64` as 4-bit values, so each slot costs
/// half a byte instead of the two bytes used by `CountingBloomFilter`. A counter
/// saturates at 15 instead of wrapping, which bounds how many insertions of the
/// same key the filter can represent but keeps the filter four times smaller.
/// Removing a key that was never inserted can still corrupt the filter when it
/// produces a false positive, which is inherent to counting Bloom filters.
pub struct CompactCountingBloomFilter {
  priv counters : FixedArray[UInt64]
  priv slot_count : Int32
  priv hash_count : Int32
  priv mut inserted : Int32
}

///|
const COMPACT_COUNTER_MAX : UInt64 = 0xFUL

///|
const COMPACT_SLOTS_PER_WORD : Int32 = 16

///|
/// Largest value a single packed counter can hold.
pub fn CompactCountingBloomFilter::counter_max() -> Int32 {
  COMPACT_COUNTER_MAX.to_int()
}

///|
/// Create a compact counting filter sized for `expected_items` and the target
/// `false_positive_rate`.
///
/// Panics if `expected_items` is not positive, the rate is not in `(0, 1)`, or
/// the requested filter would exceed the supported size.
pub fn CompactCountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> CompactCountingBloomFilter {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  let n = expected_items.to_double()
  let ln2 = 0.6931471805599453
  let bits = -(n * @math.ln(false_positive_rate)) / (ln2 * ln2)
  guard bits <= 2147483584.0 else { abort("bloom filter size is too large") }
  let slot_count = (bits.ceil().to_int() + 15) / 16 * 16
  guard slot_count <= 1073741808 else {
    abort("compact counting bloom filter size is too large")
  }
  let hash_count = (bits / n * ln2).round().to_int().max(1)
  CompactCountingBloomFilter::with_size(slot_count, hash_count)
}

///|
/// Create a compact counting filter with an explicit slot and hash count.
///
/// `slot_count` is rounded up to a multiple of 16 so counters pack evenly into
/// `UInt64` words.
pub fn CompactCountingBloomFilter::with_size(
  slot_count : Int32,
  hash_count : Int32,
) -> CompactCountingBloomFilter {
  guard slot_count > 0 && slot_count <= 1073741808 else {
    abort("slot_count must be positive and not too large")
  }
  guard hash_count > 0 else { abort("hash_count must be positive") }
  let rounded = (slot_count + 15) / 16 * 16
  {
    counters: FixedArray::make(rounded / COMPACT_SLOTS_PER_WORD, 0UL),
    slot_count: rounded,
    hash_count,
    inserted: 0,
  }
}

///|
fn CompactCountingBloomFilter::counter_at(
  self : CompactCountingBloomFilter,
  position : Int32,
) -> UInt64 {
  let word = position / COMPACT_SLOTS_PER_WORD
  let shift = position % COMPACT_SLOTS_PER_WORD * 4
  (self.counters[word] >> shift) & COMPACT_COUNTER_MAX
}

///|
fn CompactCountingBloomFilter::set_counter(
  self : CompactCountingBloomFilter,
  position : Int32,
  value : UInt64,
) -> Unit {
  let word = position / COMPACT_SLOTS_PER_WORD
  let shift = position % COMPACT_SLOTS_PER_WORD * 4
  let value = if value > COMPACT_COUNTER_MAX {
    COMPACT_COUNTER_MAX
  } else {
    value
  }
  let old = (self.counters[word] >> shift) & COMPACT_COUNTER_MAX
  let cleared = self.counters[word] ^ (old << shift)
  self.counters[word] = cleared | (value << shift)
}

///|
/// Insert `key` by incrementing every selected counter.
///
/// Counters at 15 stay saturated. The insertion counter is incremented for
/// every call, including duplicate keys.
pub fn[K : Hash] CompactCountingBloomFilter::insert(
  self : CompactCountingBloomFilter,
  key : K,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("compact counting bloom filter insertion count overflow")
  }
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, slot_count)
    let value = self.counter_at(pos)
    if value < COMPACT_COUNTER_MAX {
      self.set_counter(pos, value + 1UL)
    }
  }
  self.inserted += 1
}

///|
/// Insert `key` only when at least one selected counter is zero.
///
/// Returns `true` when the key was inserted, or `false` when every selected
/// counter was positive and the key may already be present. False positives can
/// therefore suppress an insertion that would otherwise be harmless.
pub fn[K : Hash] CompactCountingBloomFilter::insert_if_absent(
  self : CompactCountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, slot_count)
    if self.counter_at(pos) == 0UL {
      guard self.inserted < 2147483647 else {
        abort("compact counting bloom filter insertion count overflow")
      }
      for j = 0; j < self.hash_count; j = j + 1 {
        let remaining = bit_index(h1, h2, j, slot_count)
        let value = self.counter_at(remaining)
        if value < COMPACT_COUNTER_MAX {
          self.set_counter(remaining, value + 1UL)
        }
      }
      self.inserted += 1
      return true
    }
  }
  false
}

///|
/// Remove one insertion of `key` by decrementing every selected counter.
///
/// Returns `true` when all counters were positive and were decremented. A key
/// that was never inserted may still return `true` on a false positive and
/// remove another key's contribution; only remove keys known to be present.
pub fn[K : Hash] CompactCountingBloomFilter::remove(
  self : CompactCountingBloomFilter,
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
    self.set_counter(pos, self.counter_at(pos) - 1UL)
  }
  if self.inserted > 0 {
    self.inserted -= 1
  }
  true
}

///|
/// Test whether every counter selected by `key` is positive.
pub fn[K : Hash] CompactCountingBloomFilter::contains(
  self : CompactCountingBloomFilter,
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
/// The result is the smallest counter selected by `key`, capped at 15 because
/// counters saturate. It can exceed the true multiplicity when other keys share
/// those slots, and it is never lower than the number of insertions unless a
/// counter has saturated. A key that hashes to a zero counter is reported as
/// `0`.
pub fn[K : Hash] CompactCountingBloomFilter::count_of(
  self : CompactCountingBloomFilter,
  key : K,
) -> Int32 {
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  let mut minimum = COMPACT_COUNTER_MAX
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
pub fn[K : Hash] CompactCountingBloomFilter::insert_all(
  self : CompactCountingBloomFilter,
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
pub fn[K : Hash] CompactCountingBloomFilter::insert_all_if_absent(
  self : CompactCountingBloomFilter,
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
pub fn[K : Hash] CompactCountingBloomFilter::remove_all(
  self : CompactCountingBloomFilter,
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
fn CompactCountingBloomFilter::ensure_compatible(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Unit {
  guard self.slot_count == other.slot_count &&
    self.hash_count == other.hash_count else {
    abort("compact counting bloom filters must have the same slot and hash counts")
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
pub fn CompactCountingBloomFilter::merge(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Unit {
  self.ensure_compatible(other)
  guard self.inserted <= 2147483647 - other.inserted else {
    abort("compact counting bloom filter insertion count overflow")
  }
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    let mut merged = 0UL
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      let shift = lane * 4
      let a = (left >> shift) & COMPACT_COUNTER_MAX
      let b = (right >> shift) & COMPACT_COUNTER_MAX
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
pub fn CompactCountingBloomFilter::union(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
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
pub fn CompactCountingBloomFilter::intersection(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
  self.ensure_compatible(other)
  let result = CompactCountingBloomFilter::with_size(
    self.slot_count, self.hash_count,
  )
  for i = 0; i < result.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    let mut merged = 0UL
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      let shift = lane * 4
      let a = (left >> shift) & COMPACT_COUNTER_MAX
      let b = (right >> shift) & COMPACT_COUNTER_MAX
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
pub fn CompactCountingBloomFilter::is_subset_of(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      let shift = lane * 4
      if ((left >> shift) & COMPACT_COUNTER_MAX) >
        ((right >> shift) & COMPACT_COUNTER_MAX) {
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
pub fn CompactCountingBloomFilter::is_disjoint_from(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      let shift = lane * 4
      if ((left >> shift) & COMPACT_COUNTER_MAX) != 0UL &&
        ((right >> shift) & COMPACT_COUNTER_MAX) != 0UL {
        return false
      }
    }
  }
  true
}

///|
/// Test every key in `keys`, returning `false` at the first definite miss.
pub fn[K : Hash] CompactCountingBloomFilter::contains_all(
  self : CompactCountingBloomFilter,
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
pub fn[K : Hash] CompactCountingBloomFilter::contains_any(
  self : CompactCountingBloomFilter,
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
pub fn CompactCountingBloomFilter::copy(
  self : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
  {
    counters: self.counters.copy(),
    slot_count: self.slot_count,
    hash_count: self.hash_count,
    inserted: self.inserted,
  }
}

///|
/// Reset every counter and the insertion counter.
pub fn CompactCountingBloomFilter::clear(
  self : CompactCountingBloomFilter,
) -> Unit {
  for i = 0; i < self.counters.length(); i = i + 1 {
    self.counters[i] = 0UL
  }
  self.inserted = 0
}

///|
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn CompactCountingBloomFilter::count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion is currently outstanding.
pub fn CompactCountingBloomFilter::is_empty(
  self : CompactCountingBloomFilter,
) -> Bool {
  self.inserted == 0
}

///|
/// Number of addressable counters, always a multiple of 16.
pub fn CompactCountingBloomFilter::slot_count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  self.slot_count
}

///|
/// Number of counters updated per operation.
pub fn CompactCountingBloomFilter::hash_count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  self.hash_count
}

///|
/// Number of slots with a positive counter.
pub fn CompactCountingBloomFilter::occupied_slot_count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  let mut total = 0
  for i = 0; i < self.counters.length(); i = i + 1 {
    let word = self.counters[i]
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      if ((word >> (lane * 4)) & COMPACT_COUNTER_MAX) != 0UL {
        total = total + 1
      }
    }
  }
  total
}

///|
/// Fraction of slots with a positive counter, in `[0, 1]`.
pub fn CompactCountingBloomFilter::fill_ratio(
  self : CompactCountingBloomFilter,
) -> Double {
  self.occupied_slot_count().to_double() / self.slot_count.to_double()
}

///|
/// Estimate the number of distinct keys represented by the occupied slots.
///
/// Uses the same occupancy formula as `BloomFilter::estimated_item_count`, with
/// the slot count in place of the bit count.
pub fn CompactCountingBloomFilter::estimated_item_count(
  self : CompactCountingBloomFilter,
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
///
/// This is four times smaller than an equivalent `CountingBloomFilter`, which
/// uses 16 bits per slot.
pub fn CompactCountingBloomFilter::memory_bytes(
  self : CompactCountingBloomFilter,
) -> Int64 {
  self.counters.length().to_int64() * 8L
}

///|
/// Estimated false-positive rate for the current insertion count.
///
/// Uses the same formula as `BloomFilter::false_positive_rate`, with the slot
/// count in place of the bit count.
pub fn CompactCountingBloomFilter::false_positive_rate(
  self : CompactCountingBloomFilter,
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
