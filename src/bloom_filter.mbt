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

///|
fn mix64(x : UInt64) -> UInt64 {
  let mut value = x
  value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9UL
  value = (value ^ (value >> 27)) * 0x94D049BB133111EBUL
  value ^ (value >> 31)
}

///|
fn bit_index(h1 : UInt64, h2 : UInt64, i : Int32, bit_count : UInt64) -> Int32 {
  ((h1 + i.to_uint64() * h2) % bit_count).to_int()
}

///|
fn[T : Hash] key_hashes(key : T) -> (UInt64, UInt64) {
  let hasher = Hasher(seed=0x243F6A88)
  hasher.combine(key)
  let low = hasher.finalize().reinterpret_as_uint().to_uint64()
  hasher.combine_int(0x1B873593)
  let high = hasher.finalize().reinterpret_as_uint().to_uint64()
  let h1 = mix64((high << 32) | low)
  let h2 = mix64(h1 ^ 0x9E3779B97F4A7C15UL) | 1UL
  (h1, h2)
}

///|
/// Compute the standard Bloom filter layout for a capacity and target rate.
fn bloom_layout(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  let n = expected_items.to_double()
  let ln2 = 0.6931471805599453
  let bits = -(n * @math.ln(false_positive_rate)) / (ln2 * ln2)
  guard bits <= 2147483584.0 else { abort("bloom filter size is too large") }
  let bit_count = (bits.ceil().to_int() + 63) / 64 * 64
  let hash_count = (bits / n * ln2).round().to_int().max(1)
  (bit_count, hash_count)
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
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  let (bit_count, hash_count) = bloom_layout(
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
  guard bit_count > 0 && bit_count <= 2147483584 else {
    abort("bit_count must be positive and not too large")
  }
  guard hash_count > 0 else { abort("hash_count must be positive") }
  let word_count = (bit_count + 63) / 64
  {
    words: FixedArray::make(word_count, 0UL),
    bit_count: word_count * 64,
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
  guard self.inserted < 2147483647 else {
    abort("bloom filter insertion count overflow")
  }
  let bit_count = self.bit_count.to_uint64()
  let mut state = h1
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = (state % bit_count).to_int()
    let word = pos / 64
    let bit = pos % 64
    self.words[word] = self.words[word] | (1UL << bit)
    state = state + h2
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
  let bit_count = self.bit_count.to_uint64()
  let mut state = h1
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = (state % bit_count).to_int()
    let mask = 1UL << (pos % 64)
    if (self.words[pos / 64] & mask) == 0UL {
      guard self.inserted < 2147483647 else {
        abort("bloom filter insertion count overflow")
      }
      for j = i; j < self.hash_count; j = j + 1 {
        let remaining = bit_index(h1, h2, j, bit_count)
        self.words[remaining / 64] = self.words[remaining / 64] |
          (1UL << (remaining % 64))
      }
      self.inserted += 1
      return true
    }
    state = state + h2
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
  let bit_count = self.bit_count.to_uint64()
  let mut state = h1
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = (state % bit_count).to_int()
    let word = pos / 64
    let bit = pos % 64
    let mask = 1UL << bit
    let present = self.words[word] & mask
    if present == 0UL {
      return false
    }
    state = state + h2
  }
  true
}

///|
/// Test whether `key` may have been inserted.
///
/// `false` means the key is definitely absent. `true` means it is either
/// present or a false positive.
pub fn[K : Hash] BloomFilter::contains(self : BloomFilter, key : K) -> Bool {
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
  guard self.inserted <= 2147483647 - other.inserted else {
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
  let mut total = 0
  for i = 0; i < self.words.length(); i = i + 1 {
    total = total + self.words[i].popcnt()
  }
  total
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
