///|
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
  let h1 = mix64(Hash::hash(key).reinterpret_as_uint().to_uint64())
  let h2 = mix64(h1 ^ 0x9E3779B97F4A7C15UL) | 1UL
  (h1, h2)
}

///|
pub fn BloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> BloomFilter {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  let n = expected_items.to_double()
  let ln2 = 0.6931471805599453
  let bits = -(n * @math.ln(false_positive_rate)) / (ln2 * ln2)
  guard bits <= 2147483584.0 else { abort("bloom filter size is too large") }
  let bit_count = (bits.ceil().to_int() + 63) / 64 * 64
  let hash_count = (bits / n * ln2).round().to_int().max(1)
  BloomFilter::with_size(bit_count, hash_count)
}

///|
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
pub fn[K : Hash] BloomFilter::insert(self : BloomFilter, key : K) -> Unit {
  let (h1, h2) = key_hashes(key)
  let bit_count = self.bit_count.to_uint64()
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, bit_count)
    let word = pos / 64
    let bit = pos % 64
    self.words[word] = self.words[word] | (1UL << bit)
  }
  self.inserted += 1
}

///|
pub fn[K : Hash] BloomFilter::contains(self : BloomFilter, key : K) -> Bool {
  let (h1, h2) = key_hashes(key)
  let bit_count = self.bit_count.to_uint64()
  for i = 0; i < self.hash_count; i = i + 1 {
    let pos = bit_index(h1, h2, i, bit_count)
    let word = pos / 64
    let bit = pos % 64
    let mask = 1UL << bit
    let present = self.words[word] & mask
    if present == 0UL {
      return false
    }
  }
  true
}

///|
pub fn[K : Hash] BloomFilter::insert_all(
  self : BloomFilter,
  keys : ArrayView[K],
) -> Unit {
  for key in keys {
    self.insert(key)
  }
}

///|
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
pub fn BloomFilter::clear(self : BloomFilter) -> Unit {
  for i = 0; i < self.words.length(); i = i + 1 {
    self.words[i] = 0UL
  }
  self.inserted = 0
}

///|
pub fn BloomFilter::count(self : BloomFilter) -> Int32 {
  self.inserted
}

///|
pub fn BloomFilter::is_empty(self : BloomFilter) -> Bool {
  self.inserted == 0
}

///|
pub fn BloomFilter::bit_count(self : BloomFilter) -> Int32 {
  self.bit_count
}

///|
pub fn BloomFilter::hash_count(self : BloomFilter) -> Int32 {
  self.hash_count
}

///|
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
