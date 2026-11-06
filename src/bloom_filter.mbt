///|
/// A compact probabilistic set backed by a bit-packed array.
///
/// A Bloom filter can report false positives but never false negatives while
/// keys are only inserted. All bit positions are derived from a 64-bit hash
/// and double hashing; storage uses `UInt64` words so a filter with `m` bits
/// occupies approximately `m / 8` bytes.
pub struct BloomFilter {
  priv words : FixedArray[UInt64]
  priv bit_count : Int32
  priv hash_count : Int32
  priv mut inserted : Int32
}

/// Maximum number of addressable bits (2^31 - 2^6 = 2147483584).
const BLOOM_MAX_BITS : Int32 = 2147483584

/// All 64 bits set in a word.
const WORD_ALL_ONES : UInt64 = 0xFFFFFFFFFFFFFFFFUL

/// Word size in bits.
const WORD_BITS : Int32 = 64

/// Hash seed for the first 64-bit hash.
const HASH_SEED_1 : Int = 0x243F6A88

/// Hash seed for the second 64-bit hash.
const HASH_SEED_2 : Int = 0x1B873593

/// Mix64 constant 1.
const MIX64_CONST_1 : UInt64 = 0xBF58476D1CE4E5B9UL

/// Mix64 constant 2.
const MIX64_CONST_2 : UInt64 = 0x94D049BB133111EBUL

/// Mix64 constant 3 (golden ratio).
const MIX64_CONST_3 : UInt64 = 0x9E3779B97F4A7C15UL

/// Maximum insertion count before overflow (Int32::max_value()).
const MAX_INSERTIONS : Int32 = 2147483647

///|
fn mix64(x : UInt64) -> UInt64 {
  let mut value = x
  value = (value ^ (value >> 30)) * MIX64_CONST_1
  value = (value ^ (value >> 27)) * MIX64_CONST_2
  value = value ^ (value >> 31)
  value
}

///|
fn[T : Hash] key_hashes(key : T) -> (UInt64, UInt64) {
  let hasher = Hasher(seed=HASH_SEED_1)
  hasher.combine(key)
  let low = hasher.finalize().reinterpret_as_uint().to_uint64()
  hasher.combine_int(HASH_SEED_2)
  let high = hasher.finalize().reinterpret_as_uint().to_uint64()
  let h1 = mix64((high << 32) | low)
  let h2 = mix64(h1 ^ MIX64_CONST_3) | 1UL
  (h1, h2)
}

///|
/// Number of bit probes that can select a new position before the double-hash
/// sequence repeats.
///
/// A Bloom bit count is always a multiple of 64. When it is also a power of two,
/// wrapping the 64-bit probe state subtracts a multiple of the bit count, so the
/// position sequence is periodic with period `bit_count / gcd(step, bit_count)`.
/// Wider hash counts can then stop after one cycle instead of rechecking bits
/// that are already known to be set or clear. Other bit counts keep every probe
/// because a 64-bit wrap can move later probes outside the first cycle.
fn bloom_effective_probes(
  bit_count : Int32,
  hash_count : Int32,
  h2 : UInt64,
) -> Int32 {
  counting_effective_probes(hash_count, h2, bit_count.to_uint64())
}

///|
/// Whether every bit in a bit-packed word array is set.
fn words_all_set(words : FixedArray[UInt64]) -> Bool {
  for i = 0; i < words.length(); i = i + 1 {
    if words[i] != WORD_ALL_ONES {
      return false
    }
  }
  true
}

///|
/// Whether scanning the whole backing array is cheaper than walking `probes`
/// positions.
///
/// A completely full filter cannot change, so one scan of the backing words can
/// replace a long probe walk. Ordinary layouts (a handful of probes over many
/// words) stay on the probe path; the threshold only selects the scan when the
/// effective walk is already wider than the word array.
fn probe_walk_exceeds_words(probes : Int32, word_count : Int32) -> Bool {
  probes > WORD_BITS && probes > word_count
}

///|
/// Whether every addressable bit is currently set.
fn BloomFilter::all_bits_set(self : BloomFilter) -> Bool {
  words_all_set(self.words)
}

///|
/// Whether a full-filter scan is cheaper than walking `probes` positions.
///
/// A completely full filter cannot change, so one scan of the backing words can
/// replace a long probe walk. Ordinary layouts (a handful of probes over many
/// words) stay on the probe path; the threshold only selects the scan when the
/// effective walk is already wider than the word array.
fn BloomFilter::should_check_full(
  self : BloomFilter,
  probes : Int32,
) -> Bool {
  probe_walk_exceeds_words(probes, self.words.length())
}

///|
/// Compute the standard Bloom filter layout for a capacity and target rate.
fn bloom_layout(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  let raw_bits = bloom_raw_bit_count(expected_items, false_positive_rate)
  guard raw_bits <= BLOOM_MAX_BITS.to_double() else {
    abort("bloom filter size is too large")
  }
  let bit_count = round_up_to_alignment(raw_bits.ceil().to_int(), WORD_BITS)
  let hash_count = bloom_hash_count(raw_bits, expected_items)
  (bit_count, hash_count)
}

///|
/// Compute the bit and hash counts that `BloomFilter::new` would use.
///
/// This is useful for planning memory before allocating a filter. The returned
/// bit count is already rounded up to a whole 64-bit word, so it matches
/// `bit_count()` on a filter built with the same arguments. Panics for the same
/// invalid arguments as `BloomFilter::new`.
pub fn BloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  validate_expected_items(expected_items)
  validate_false_positive_rate(false_positive_rate)
  bloom_layout(expected_items, false_positive_rate)
}

///|
/// Create a filter sized for `expected_items` with the target
/// `false_positive_rate`.
///
/// The bit count and hash count are derived from the standard Bloom filter
/// formulas. Panics if `expected_items` is not positive, the rate is not in
/// `(0, 1)`, or the requested filter would exceed the supported size.
pub fn BloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> BloomFilter {
  let (bit_count, hash_count) = BloomFilter::optimal_size(
    expected_items, false_positive_rate,
  )
  BloomFilter::with_size(bit_count, hash_count)
}

///|
/// Create a filter with an explicit bit count and number of hash functions.
///
/// `bit_count` is rounded up to a whole 64-bit word. This constructor is
/// useful when reproducing a pre-computed configuration or when tuning the
/// trade-off between memory and false-positive rate directly.
pub fn BloomFilter::with_size(
  bit_count : Int32,
  hash_count : Int32,
) -> BloomFilter {
  guard bit_count > 0 && bit_count <= BLOOM_MAX_BITS else {
    abort("bit_count must be positive and not too large")
  }
  validate_hash_count(hash_count)
  let rounded = round_up_to_alignment(bit_count, WORD_BITS)
  {
    words: FixedArray::make(rounded / WORD_BITS, 0UL),
    bit_count: rounded,
    hash_count,
    inserted: 0,
  }
}

///|
/// Insert a key whose two hash values have already been computed.
fn BloomFilter::insert_hashes(
    self : BloomFilter,
    h1 : UInt64,
    h2 : UInt64,
    ) -> Unit {
   // Guard every insertion path, including the full-filter shortcut below:
   // that path also increments the counter and could otherwise overflow it.
   guard self.inserted < MAX_INSERTIONS else {
       abort("bloom filter insertion count overflow")
   }
   let bit_count = self.bit_count.to_uint64()
   let probes = bloom_effective_probes(self.bit_count, self.hash_count, h2)
   // A completely full filter cannot change, so skip the nominal probe walk.
   // Besides wide non-power-of-two layouts, this also covers power-of-two
   // layouts whose double-hash period is long.
   if self.should_check_full(probes) && self.all_bits_set() {
       self.inserted += 1
       return
   }
   let mut probe = h1
   for i = 0; i < probes; i = i + 1 {
       let pos = (probe % bit_count).to_int()
       let word = pos / WORD_BITS
       let bit = pos % WORD_BITS
       self.words[word] = self.words[word] | (1UL << bit)
       probe = probe + h2
   }
   self.inserted += 1
}

///|
/// Insert `key` by setting every bit selected by the hash functions.
///
/// Inserting the same key more than once is allowed. The insertion counter is
/// incremented on every call, including duplicates.
pub fn[K : Hash] BloomFilter::insert(self : BloomFilter, key : K) -> Unit {
  let (h1, h2) = key_hashes(key)
  self.insert_hashes(h1, h2)
}

///|
/// Insert a key with precomputed hashes only when it is definitely absent.
fn BloomFilter::insert_if_absent_hashes(
    self : BloomFilter,
    h1 : UInt64,
    h2 : UInt64,
    ) -> Bool {
    // Every selected bit is set on a full filter, so the conditional insertion
    // must report a false positive without walking a wide probe sequence.
    let bit_count = self.bit_count.to_uint64()
    let probes = bloom_effective_probes(self.bit_count, self.hash_count, h2)
    if self.should_check_full(probes) && self.all_bits_set() {
        return false
    }
    // Check for overflow before entering the probe sequence
    guard self.inserted < MAX_INSERTIONS else {
        abort("bloom filter insertion count overflow")
    }
    let mut probe = h1
    for i = 0; i < probes; i = i + 1 {
        let pos = (probe % bit_count).to_int()
        let mask = 1UL << (pos % WORD_BITS)
        if (self.words[pos / WORD_BITS] & mask) == 0UL {
            let mut remaining_probe = probe
            for j = i; j < probes; j = j + 1 {
                let remaining = (remaining_probe % bit_count).to_int()
                self.words[remaining / WORD_BITS] = self.words[remaining / WORD_BITS] |
                    (1UL << (remaining % WORD_BITS))
                remaining_probe = remaining_probe + h2
            }
            self.inserted += 1
            return true
        }
        probe = probe + h2
    }
    false
}

///|
/// Insert `key` only when it is definitely absent.
///
/// Returns `true` when the key was inserted, or `false` when every selected bit
/// was already set and the key may already be present. False positives can
/// therefore suppress an insertion that would otherwise be harmless.
pub fn[K : Hash] BloomFilter::insert_if_absent(
  self : BloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  self.insert_if_absent_hashes(h1, h2)
}

///|
/// Test a key whose two hash values have already been computed.
fn BloomFilter::contains_hashes(
  self : BloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  // The insertion counter is zero only while no bit is set, so no key can be
  // reported present. This avoids a wide probe walk on a non-power-of-two bit
  // count, where the double-hash cycle shortcut does not apply.
  if self.inserted == 0 {
    return false
  }
  // A full filter reports every key present; avoid probing a wide position
  // sequence just to rediscover bits that are already set.
  let bit_count = self.bit_count.to_uint64()
  let probes = bloom_effective_probes(self.bit_count, self.hash_count, h2)
  if self.should_check_full(probes) && self.all_bits_set() {
    return true
  }
  let mut probe = h1
  for i = 0; i < probes; i = i + 1 {
    let pos = (probe % bit_count).to_int()
    let word = pos / WORD_BITS
    let bit = pos % WORD_BITS
    let mask = 1UL << bit
    let present = self.words[word] & mask
    if present == 0UL {
      return false
    }
    probe = probe + h2
  }
  true
}

///|
/// Test whether `key` may have been inserted.
///
/// `false` means the key is definitely absent. `true` means it is either
/// present or a false positive.
pub fn[K : Hash] BloomFilter::contains(self : BloomFilter, key : K) -> Bool {
  // No insertion has happened, so no bit is set and hashing the key would be
  // wasted work.
  if self.inserted == 0 {
    return false
  }
  let (h1, h2) = key_hashes(key)
  self.contains_hashes(h1, h2)
}

///|
/// Insert every key in `keys`.
///
/// An empty view is a no-op.
pub fn[K : Hash] BloomFilter::insert_all(
  self : BloomFilter,
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
pub fn[K : Hash] BloomFilter::insert_all_if_absent(
  self : BloomFilter,
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
pub fn[K : Hash] BloomFilter::contains_all(
  self : BloomFilter,
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
fn BloomFilter::ensure_compatible(
  self : BloomFilter,
  other : BloomFilter,
) -> Unit {
  guard self.bit_count == other.bit_count && self.hash_count == other.hash_count else {
    abort("bloom filters must have the same bit and hash counts")
  }
}

///|
/// Merge every bit of `other` into `self` in place.
///
/// Both filters must use the same bit and hash counts. After merging, `self`
/// reports every key reported by either input. The insertion counter becomes
/// the sum of the input counts, a conservative upper bound when keys overlap.
pub fn BloomFilter::merge(self : BloomFilter, other : BloomFilter) -> Unit {
  self.ensure_compatible(other)
  if other.inserted == 0 {
    return
  }
  if self.inserted == 0 {
    for i = 0; i < self.words.length(); i = i + 1 {
      self.words[i] = other.words[i]
    }
    self.inserted = other.inserted
    return
  }
  guard self.inserted <= MAX_INSERTIONS - other.inserted else {
    abort("bloom filter insertion count overflow")
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
/// union of their bit arrays, so it never reports false negatives for keys that
/// either input reported present. The insertion count is the sum of the input
/// counts, which is a conservative upper bound because keys may overlap.
pub fn BloomFilter::union(
  self : BloomFilter,
  other : BloomFilter,
) -> BloomFilter {
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
pub fn BloomFilter::intersection(
  self : BloomFilter,
  other : BloomFilter,
) -> BloomFilter {
  self.ensure_compatible(other)
  if self.inserted == 0 || other.inserted == 0 {
    let result = BloomFilter::with_size(self.bit_count, self.hash_count)
    result.inserted = self.inserted.min(other.inserted)
    return result
  }
  let result = BloomFilter::with_size(self.bit_count, self.hash_count)
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
pub fn BloomFilter::is_subset_of(
  self : BloomFilter,
  other : BloomFilter,
) -> Bool {
  self.ensure_compatible(other)
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
pub fn BloomFilter::is_disjoint_from(
  self : BloomFilter,
  other : BloomFilter,
) -> Bool {
  self.ensure_compatible(other)
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
pub fn BloomFilter::copy(self : BloomFilter) -> BloomFilter {
  {
    words: self.words.copy(),
    bit_count: self.bit_count,
    hash_count: self.hash_count,
    inserted: self.inserted,
  }
}

///|
/// Test whether at least one key in `keys` may be present.
///
/// Returns `false` for an empty view.
pub fn[K : Hash] BloomFilter::contains_any(
  self : BloomFilter,
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
/// Clear every bit and reset the insertion counter.
pub fn BloomFilter::clear(self : BloomFilter) -> Unit {
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
pub fn BloomFilter::count(self : BloomFilter) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion has happened since creation or the last `clear`.
pub fn BloomFilter::is_empty(self : BloomFilter) -> Bool {
  self.inserted == 0
}

///|
/// Number of addressable bits, always a multiple of 64.
pub fn BloomFilter::bit_count(self : BloomFilter) -> Int32 {
  self.bit_count
}

///|
/// Number of bit positions set or tested per operation.
pub fn BloomFilter::hash_count(self : BloomFilter) -> Int32 {
  self.hash_count
}

///|
/// Number of bits currently set to one.
pub fn BloomFilter::set_bit_count(self : BloomFilter) -> Int32 {
  if self.inserted == 0 {
    return 0
  }
  let mut total = 0
  for i = 0; i < self.words.length(); i = i + 1 {
    total = total + self.words[i].popcnt()
  }
  total
}

///|
/// Whether every addressable bit is set.
///
/// A full filter reports every key as present. Inserting a key still advances
/// the insertion counter, but it cannot change the filter's membership state.
pub fn BloomFilter::is_full(self : BloomFilter) -> Bool {
  if self.inserted == 0 {
    return false
  }
  self.all_bits_set()
}

///|
fn BloomFilter::has_set_bit(self : BloomFilter) -> Bool {
  // An insertion count of zero implies no bit is set in a valid filter, so the
  // scalable set checks can skip empty slices without touching their words.
  // A deserialized count-only slice can carry a positive count with zero bits,
  // so only the zero-count case is eligible for this shortcut.
  if self.inserted == 0 {
    return false
  }
  for i = 0; i < self.words.length(); i = i + 1 {
    if self.words[i] != 0UL {
      return true
    }
  }
  false
}

///|
/// Fraction of addressable bits currently set to one, in `[0, 1]`.
pub fn BloomFilter::fill_ratio(self : BloomFilter) -> Double {
  self.set_bit_count().to_double() / self.bit_count.to_double()
}

///|
/// Estimate the number of distinct keys represented by the current set bits.
///
/// Uses `-(m / k) * ln(1 - X / m)`, where `X` is the number of set bits. The
/// estimate is `0` for an empty filter and infinite once every bit is set.
pub fn BloomFilter::estimated_item_count(self : BloomFilter) -> Double {
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
pub fn BloomFilter::memory_bytes(self : BloomFilter) -> Int64 {
  self.words.length().to_int64() * 8L
}

///|
/// Estimated false-positive rate for the current insertion count.
///
/// The estimate uses `(1 - exp(-k * n / m))^k`, where `n` is the insertion
/// count, `k` the hash count, and `m` the bit count. It returns `0` for an
/// empty filter.
pub fn BloomFilter::false_positive_rate(self : BloomFilter) -> Double {
  if self.inserted == 0 {
    0.0
  } else {
    let n = self.inserted.to_double()
    let k = self.hash_count.to_double()
    let m = self.bit_count.to_double()
    @math.pow(1.0 - @math.exp(-k * n / m), k)
  }
}
