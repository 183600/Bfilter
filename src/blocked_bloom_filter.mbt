///|
/// A cache-friendly Bloom filter that keeps every hash position for a key
/// inside one small block.
///
/// A classic Bloom filter probes bits scattered across the whole array, which
/// can cause one cache miss per hash function. This variant first selects a
/// single 512-bit block from the key hash and then derives all positions within
/// that block. A query therefore touches at most one cache line, at the cost of
/// a slightly higher false-positive rate because blocks fill unevenly.
pub struct BlockedBloomFilter {
  priv words : FixedArray[UInt64]
  priv bit_count : Int32
  priv hash_count : Int32
  priv mut inserted : Int32
}

///|
const BLOCKED_BLOCK_BITS : Int32 = 512

///|
const BLOCKED_BLOCK_WORDS : Int32 = 8

///|
const BLOCKED_MAX_BITS : Int32 = 2147483136

///|
/// Number of probes that can select a new bit inside one blocked-filter block.
///
/// Every probe stays in the selected 512-bit block, and the step is odd, so the
/// offset sequence repeats after at most 512 probes. A wider hash count can stop
/// after one cycle instead of rescanning bits that are already known.
fn blocked_effective_probes(hash_count : Int32, h2 : UInt64) -> Int32 {
  counting_effective_probes(hash_count, h2, BLOCKED_BLOCK_BITS.to_uint64())
}

///|
/// Compute the Bloom layout used by a blocked filter.
fn blocked_bloom_layout(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  let n = expected_items.to_double()
  let ln2 = 0.6931471805599453
  let bits = -(n * @math.ln(false_positive_rate)) / (ln2 * ln2)
  guard bits <= BLOCKED_MAX_BITS.to_double() else {
    abort("blocked bloom filter size is too large")
  }
  let bit_count = (bits.ceil().to_int() + BLOCKED_BLOCK_BITS - 1) /
    BLOCKED_BLOCK_BITS *
    BLOCKED_BLOCK_BITS
  let hash_count = (bits / n * ln2).round().to_int().max(1)
  (bit_count, hash_count)
}

///|
/// Compute the bit and hash counts that `BlockedBloomFilter::new` would use.
///
/// The returned bit count is already rounded up to a whole 512-bit block, so it
/// matches `bit_count()` on a filter built with the same arguments. Panics for
/// the same invalid arguments as `BlockedBloomFilter::new`.
pub fn BlockedBloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  blocked_bloom_layout(expected_items, false_positive_rate)
}

///|
/// Create a blocked filter sized for `expected_items` with the target
/// `false_positive_rate`.
///
/// The bit count is derived from the standard Bloom filter formulas and rounded
/// up to a whole number of 512-bit blocks. Panics if `expected_items` is not
/// positive, the rate is not in `(0, 1)`, or the filter would exceed the
/// supported size.
pub fn BlockedBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> BlockedBloomFilter {
  let (bit_count, hash_count) = BlockedBloomFilter::optimal_size(
    expected_items, false_positive_rate,
  )
  BlockedBloomFilter::with_size(bit_count, hash_count)
}

///|
/// Create a blocked filter with an explicit bit count and number of hash
/// functions.
///
/// `bit_count` is rounded up to a whole 512-bit block. The resulting
/// `bit_count()` is always a multiple of 512, and `memory_bytes()` reports the
/// backing word array.
pub fn BlockedBloomFilter::with_size(
  bit_count : Int32,
  hash_count : Int32,
) -> BlockedBloomFilter {
  guard bit_count > 0 && bit_count <= BLOCKED_MAX_BITS else {
    abort("bit_count must be positive and not too large")
  }
  guard hash_count > 0 else { abort("hash_count must be positive") }
  let rounded = (bit_count + BLOCKED_BLOCK_BITS - 1) /
    BLOCKED_BLOCK_BITS *
    BLOCKED_BLOCK_BITS
  let block_count = rounded / BLOCKED_BLOCK_BITS
  {
    words: FixedArray::make(block_count * BLOCKED_BLOCK_WORDS, 0UL),
    bit_count: rounded,
    hash_count,
    inserted: 0,
  }
}

///|
fn BlockedBloomFilter::block_base(
  self : BlockedBloomFilter,
  h1 : UInt64,
) -> Int32 {
  let block_hash = mix64(h1 ^ 0xD6E8FEB86659FD93UL)
  let block_count = (self.bit_count / BLOCKED_BLOCK_BITS).to_uint64()
  (block_hash % block_count).to_int() * BLOCKED_BLOCK_BITS
}

///|
/// Whether every addressable bit is currently set.
fn BlockedBloomFilter::all_bits_set(self : BlockedBloomFilter) -> Bool {
  for i = 0; i < self.words.length(); i = i + 1 {
    if self.words[i] != 0xFFFFFFFFFFFFFFFFUL {
      return false
    }
  }
  true
}

///|
/// Whether a full-filter scan is cheaper than walking `probes` positions.
///
/// Every probe stays inside one 512-bit block, so the effective walk is capped
/// at one block. The word scan wins only for small filters whose backing array
/// is shorter than that walk; larger layouts stay on the probe path.
fn BlockedBloomFilter::should_check_full(
  self : BlockedBloomFilter,
  probes : Int32,
) -> Bool {
  probes > 64 && probes > self.words.length()
}

///|
/// Insert `key` by setting every selected bit in its block.
///
/// Inserting the same key more than once is allowed. The insertion counter is
/// incremented on every call, including duplicates.
pub fn[K : Hash] BlockedBloomFilter::insert(
  self : BlockedBloomFilter,
  key : K,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("blocked bloom filter insertion count overflow")
  }
  let (h1, h2) = key_hashes(key)
  let base = self.block_base(h1)
  let block_bits = BLOCKED_BLOCK_BITS.to_uint64()
  let step = (h2 % block_bits).to_int()
  let mut offset = (h1 % block_bits).to_int()
  let probes = blocked_effective_probes(self.hash_count, h2)
  // A completely full filter cannot change, so skip the block probe walk.
  if self.should_check_full(probes) && self.all_bits_set() {
    self.inserted += 1
    return
  }
  for i = 0; i < probes; i = i + 1 {
    let pos = base + offset
    let word = pos / 64
    let bit = pos % 64
    self.words[word] = self.words[word] | (1UL << bit)
    offset = offset + step
    if offset >= BLOCKED_BLOCK_BITS {
      offset = offset - BLOCKED_BLOCK_BITS
    }
  }
  self.inserted += 1
}

///|
/// Insert `key` only when it is definitely absent.
///
/// Returns `true` when the key was inserted, or `false` when every selected bit
/// was already set and the key may already be present. False positives can
/// therefore suppress an insertion that would otherwise be harmless.
pub fn[K : Hash] BlockedBloomFilter::insert_if_absent(
  self : BlockedBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  let base = self.block_base(h1)
  let block_bits = BLOCKED_BLOCK_BITS.to_uint64()
  let step = (h2 % block_bits).to_int()
  let mut offset = (h1 % block_bits).to_int()
  let probes = blocked_effective_probes(self.hash_count, h2)
  // Every selected bit is already set on a full filter, so the conditional
  // insertion must report a false positive without walking the block.
  if self.should_check_full(probes) && self.all_bits_set() {
    return false
  }
  for i = 0; i < probes; i = i + 1 {
    let pos = base + offset
    let mask = 1UL << (pos % 64)
    if (self.words[pos / 64] & mask) == 0UL {
      guard self.inserted < 2147483647 else {
        abort("blocked bloom filter insertion count overflow")
      }
      let mut remaining = offset
      for j = i; j < probes; j = j + 1 {
        let target = base + remaining
        self.words[target / 64] = self.words[target / 64] |
          (1UL << (target % 64))
        remaining = remaining + step
        if remaining >= BLOCKED_BLOCK_BITS {
          remaining = remaining - BLOCKED_BLOCK_BITS
        }
      }
      self.inserted += 1
      return true
    }
    offset = offset + step
    if offset >= BLOCKED_BLOCK_BITS {
      offset = offset - BLOCKED_BLOCK_BITS
    }
  }
  false
}

///|
/// Test whether `key` may have been inserted.
///
/// `false` means the key is definitely absent. `true` means it is either
/// present or a false positive.
pub fn[K : Hash] BlockedBloomFilter::contains(
  self : BlockedBloomFilter,
  key : K,
) -> Bool {
  // No insertion has happened, so no bit can be set. Avoid probing a block on
  // an empty filter.
  if self.inserted == 0 {
    return false
  }
  let (h1, h2) = key_hashes(key)
  let base = self.block_base(h1)
  let block_bits = BLOCKED_BLOCK_BITS.to_uint64()
  let step = (h2 % block_bits).to_int()
  let mut offset = (h1 % block_bits).to_int()
  let probes = blocked_effective_probes(self.hash_count, h2)
  // A full filter reports every key present; avoid walking the block cycle.
  if self.should_check_full(probes) && self.all_bits_set() {
    return true
  }
  for i = 0; i < probes; i = i + 1 {
    let pos = base + offset
    let mask = 1UL << (pos % 64)
    if (self.words[pos / 64] & mask) == 0UL {
      return false
    }
    offset = offset + step
    if offset >= BLOCKED_BLOCK_BITS {
      offset = offset - BLOCKED_BLOCK_BITS
    }
  }
  true
}

///|
/// Insert every key in `keys`.
///
/// An empty view is a no-op.
pub fn[K : Hash] BlockedBloomFilter::insert_all(
  self : BlockedBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  for key in keys {
    self.insert(key)
  }
}

///|
/// Insert every key that is definitely absent and return how many were added.
///
/// Duplicate keys within `keys` and keys already represented by every selected
/// bit are skipped. An empty view returns `0`.
pub fn[K : Hash] BlockedBloomFilter::insert_all_if_absent(
  self : BlockedBloomFilter,
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
/// Test every key in `keys`, returning `false` as soon as one is definitely
/// absent. An empty view returns `true`.
pub fn[K : Hash] BlockedBloomFilter::contains_all(
  self : BlockedBloomFilter,
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
pub fn[K : Hash] BlockedBloomFilter::contains_any(
  self : BlockedBloomFilter,
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
fn BlockedBloomFilter::ensure_compatible(
  self : BlockedBloomFilter,
  other : BlockedBloomFilter,
) -> Unit {
  guard self.bit_count == other.bit_count && self.hash_count == other.hash_count else {
    abort("blocked bloom filters must have the same bit and hash counts")
  }
}

///|
/// Merge every bit of `other` into `self` in place.
///
/// Both filters must use the same bit and hash counts. After merging, `self`
/// reports every key reported by either input. The insertion counter becomes
/// the sum of the input counts, a conservative upper bound when keys overlap.
pub fn BlockedBloomFilter::merge(
  self : BlockedBloomFilter,
  other : BlockedBloomFilter,
) -> Unit {
  self.ensure_compatible(other)
  // An empty filter contributes neither bits nor insertions, so avoid scanning
  // the whole bit array. `inserted == 0` implies no bit is set in a valid
  // filter; deserialization rejects a zero count with set bits.
  if other.inserted == 0 {
    return
  }
  // An empty receiver has no bits to preserve, so copy the source words instead
  // of OR-ing them into zeroed storage.
  if self.inserted == 0 {
    for i = 0; i < self.words.length(); i = i + 1 {
      self.words[i] = other.words[i]
    }
    self.inserted = other.inserted
    return
  }
  guard self.inserted <= 2147483647 - other.inserted else {
    abort("blocked bloom filter insertion count overflow")
  }
  for i = 0; i < self.words.length(); i = i + 1 {
    self.words[i] = self.words[i] | other.words[i]
  }
  self.inserted += other.inserted
}

///|
/// Build a new filter containing every key present in either filter.
///
/// Both filters must use the same bit and hash counts. The result uses the
/// union of their bit arrays. The insertion count is the sum of the input
/// counts, which is a conservative upper bound because keys may overlap.
pub fn BlockedBloomFilter::union(
  self : BlockedBloomFilter,
  other : BlockedBloomFilter,
) -> BlockedBloomFilter {
  let result = self.copy()
  result.merge(other)
  result
}

///|
/// Build a new filter containing only the keys reported present by both
/// filters.
///
/// Both filters must use the same bit and hash counts. The result uses the
/// intersection of their bit arrays. The insertion count is the smaller of the
/// input counts, a conservative upper bound because the intersection cannot be
/// larger than either input.
pub fn BlockedBloomFilter::intersection(
  self : BlockedBloomFilter,
  other : BlockedBloomFilter,
) -> BlockedBloomFilter {
  self.ensure_compatible(other)
  // An empty operand has no set bits, so the intersection is empty regardless
  // of the other filter. The result still keeps the shared layout.
  if self.inserted == 0 || other.inserted == 0 {
    return BlockedBloomFilter::with_size(self.bit_count, self.hash_count)
  }
  let result = BlockedBloomFilter::with_size(self.bit_count, self.hash_count)
  for i = 0; i < result.words.length(); i = i + 1 {
    result.words[i] = self.words[i] & other.words[i]
  }
  result.inserted = self.inserted.min(other.inserted)
  result
}

///|
/// Whether every bit set in `self` is also set in `other`.
///
/// Both filters must use the same bit and hash counts. A `true` result means
/// every key reported present by `self` is also reported present by `other`.
pub fn BlockedBloomFilter::is_subset_of(
  self : BlockedBloomFilter,
  other : BlockedBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  // The empty filter is a subset of every filter.
  if self.inserted == 0 {
    return true
  }
  for i = 0; i < self.words.length(); i = i + 1 {
    if (self.words[i] & other.words[i]) != self.words[i] {
      return false
    }
  }
  true
}

///|
/// Whether `self` and `other` are definitely disjoint.
///
/// Both filters must use the same bit and hash counts. Returns `true` only when
/// no bit is set in both filters, which guarantees that no key can be reported
/// present by both. A `false` result is inconclusive because a bit set in both
/// filters may come from different keys.
pub fn BlockedBloomFilter::is_disjoint_from(
  self : BlockedBloomFilter,
  other : BlockedBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  // An empty filter cannot share a set bit with anything.
  if self.inserted == 0 || other.inserted == 0 {
    return true
  }
  for i = 0; i < self.words.length(); i = i + 1 {
    if (self.words[i] & other.words[i]) != 0UL {
      return false
    }
  }
  true
}

///|
/// Return an independent copy of the filter.
///
/// Later inserts or clears on either filter do not affect the other.
pub fn BlockedBloomFilter::copy(
  self : BlockedBloomFilter,
) -> BlockedBloomFilter {
  {
    words: self.words.copy(),
    bit_count: self.bit_count,
    hash_count: self.hash_count,
    inserted: self.inserted,
  }
}

///|
/// Clear every bit and reset the insertion counter.
pub fn BlockedBloomFilter::clear(self : BlockedBloomFilter) -> Unit {
  // A valid empty filter has no set bit, so there is nothing to zero.
  if self.inserted == 0 {
    return
  }
  for i = 0; i < self.words.length(); i = i + 1 {
    self.words[i] = 0UL
  }
  self.inserted = 0
}

///|
/// Number of insertions since creation or the last `clear`.
pub fn BlockedBloomFilter::count(self : BlockedBloomFilter) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion has happened since creation or the last `clear`.
pub fn BlockedBloomFilter::is_empty(self : BlockedBloomFilter) -> Bool {
  self.inserted == 0
}

///|
/// Number of addressable bits, always a multiple of 512.
pub fn BlockedBloomFilter::bit_count(self : BlockedBloomFilter) -> Int32 {
  self.bit_count
}

///|
/// Number of 512-bit blocks backing the filter.
pub fn BlockedBloomFilter::block_count(self : BlockedBloomFilter) -> Int32 {
  self.bit_count / BLOCKED_BLOCK_BITS
}

///|
/// Number of bit positions set or tested per operation.
pub fn BlockedBloomFilter::hash_count(self : BlockedBloomFilter) -> Int32 {
  self.hash_count
}

///|
/// Number of bits currently set to one.
pub fn BlockedBloomFilter::set_bit_count(self : BlockedBloomFilter) -> Int32 {
  let mut total = 0
  for i = 0; i < self.words.length(); i = i + 1 {
    total = total + self.words[i].popcnt()
  }
  total
}

///|
/// Fraction of addressable bits currently set to one, in `[0, 1]`.
pub fn BlockedBloomFilter::fill_ratio(self : BlockedBloomFilter) -> Double {
  self.set_bit_count().to_double() / self.bit_count.to_double()
}

///|
/// Estimate the number of distinct keys represented by the current set bits.
///
/// Uses `-(m / k) * ln(1 - X / m)`, where `X` is the number of set bits. The
/// estimate is `0` for an empty filter and infinite once every bit is set.
pub fn BlockedBloomFilter::estimated_item_count(
  self : BlockedBloomFilter,
) -> Double {
  let m = self.bit_count.to_double()
  let x = self.set_bit_count().to_double()
  if x == 0.0 {
    0.0
  } else if x >= m {
    @double.infinity
  } else {
    -(m / self.hash_count.to_double()) * @math.ln(1.0 - x / m)
  }
}

///|
/// Number of bytes occupied by the bit array.
pub fn BlockedBloomFilter::memory_bytes(self : BlockedBloomFilter) -> Int64 {
  self.words.length().to_int64() * 8L
}

///|
/// Estimated false-positive rate for the current insertion count.
///
/// The estimate uses `(1 - exp(-k * n / m))^k`, where `n` is the insertion
/// count, `k` the hash count, and `m` the bit count. It returns `0` for an
/// empty filter.
pub fn BlockedBloomFilter::false_positive_rate(
  self : BlockedBloomFilter,
) -> Double {
  if self.inserted == 0 {
    0.0
  } else {
    let n = self.inserted.to_double()
    let k = self.hash_count.to_double()
    let m = self.bit_count.to_double()
    @math.pow(1.0 - @math.exp(-k * n / m), k)
  }
}
