///|
pub struct CountingBloomFilter {
  priv counters : FixedArray[UInt64]
  priv slot_count : Int32
  priv hash_count : Int32
  priv mut inserted : Int32
}

///|
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
pub fn CountingBloomFilter::with_size(
  slot_count : Int32,
  hash_count : Int32,
) -> CountingBloomFilter {
  guard slot_count > 0 && slot_count <= 2147483584 else {
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
  let old = (self.counters[word] >> shift) & 0xFFFFUL
  let cleared = self.counters[word] ^ (old << shift)
  self.counters[word] = cleared | (value << shift)
}

///|
pub fn[K : Hash] CountingBloomFilter::insert(
  self : CountingBloomFilter,
  key : K,
) -> Unit {
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
    self.set_counter(pos, self.counter_at(pos) - 1UL)
  }
  if self.inserted > 0 {
    self.inserted -= 1
  }
  true
}

///|
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
pub fn[K : Hash] CountingBloomFilter::insert_all(
  self : CountingBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  for key in keys {
    self.insert(key)
  }
}

///|
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
pub fn CountingBloomFilter::clear(self : CountingBloomFilter) -> Unit {
  for i = 0; i < self.counters.length(); i = i + 1 {
    self.counters[i] = 0UL
  }
  self.inserted = 0
}

///|
pub fn CountingBloomFilter::count(self : CountingBloomFilter) -> Int32 {
  self.inserted
}

///|
pub fn CountingBloomFilter::is_empty(self : CountingBloomFilter) -> Bool {
  self.inserted == 0
}

///|
pub fn CountingBloomFilter::slot_count(self : CountingBloomFilter) -> Int32 {
  self.slot_count
}

///|
pub fn CountingBloomFilter::hash_count(self : CountingBloomFilter) -> Int32 {
  self.hash_count
}

///|
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
