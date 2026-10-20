///|
pub struct CuckooFilter {
  priv buckets : FixedArray[Byte]
  priv bucket_count : Int32
  priv bucket_size : Int32
  priv mut inserted : Int32
}

///|
fn next_power_of_two(n : Int32) -> Int32 {
  let mut result = 1
  while result < n {
    result = result * 2
  }
  result
}

///|
fn fingerprint_hash(fingerprint : Byte) -> UInt64 {
  mix64(fingerprint.to_uint64() * 0x9E3779B97F4A7C15UL)
}

///|
pub fn CuckooFilter::new(expected_items : Int32) -> CuckooFilter {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard expected_items <= 1073741823 else {
    abort("expected_items is too large")
  }
  let bucket_size = 4
  let bucket_count = (expected_items * 2 - 1) / bucket_size + 1
  CuckooFilter::with_size(bucket_count, bucket_size)
}

///|
pub fn CuckooFilter::with_size(
  bucket_count : Int32,
  bucket_size : Int32,
) -> CuckooFilter {
  guard bucket_count > 0 && bucket_count <= 1073741824 else {
    abort("bucket_count must be positive and not too large")
  }
  guard bucket_size > 0 else { abort("bucket_size must be positive") }
  let bucket_count = next_power_of_two(bucket_count)
  guard bucket_size <= 2147483647 / bucket_count else {
    abort("cuckoo filter size is too large")
  }
  let slot_count = bucket_count * bucket_size
  {
    buckets: FixedArray::make(slot_count, b'\x00'),
    bucket_count,
    bucket_size,
    inserted: 0,
  }
}

///|
fn CuckooFilter::alternate_index(
  self : CuckooFilter,
  index : Int32,
  fingerprint : Byte,
) -> Int32 {
  let mask = (self.bucket_count - 1).to_uint64()
  (index.to_uint64() ^ (fingerprint_hash(fingerprint) & mask)).to_int()
}

///|
fn[T : Hash] CuckooFilter::key_info(
  self : CuckooFilter,
  key : T,
) -> (Int32, Byte) {
  let hash = mix64(Hash::hash(key).reinterpret_as_uint().to_uint64())
  let mask = (self.bucket_count - 1).to_uint64()
  let index = (hash & mask).to_int()
  let fingerprint = ((hash >> 32) % 255UL + 1UL).to_byte()
  (index, fingerprint)
}

///|
fn CuckooFilter::find_empty(self : CuckooFilter, bucket : Int32) -> Int32 {
  let base = bucket * self.bucket_size
  for slot = 0; slot < self.bucket_size; slot = slot + 1 {
    if self.buckets[base + slot].to_int() == 0 {
      return slot
    }
  }
  -1
}

///|
fn CuckooFilter::bucket_contains(
  self : CuckooFilter,
  bucket : Int32,
  fingerprint : Byte,
) -> Bool {
  let base = bucket * self.bucket_size
  for slot = 0; slot < self.bucket_size; slot = slot + 1 {
    if self.buckets[base + slot] == fingerprint {
      return true
    }
  }
  false
}

///|
fn CuckooFilter::bucket_remove(
  self : CuckooFilter,
  bucket : Int32,
  fingerprint : Byte,
) -> Bool {
  let base = bucket * self.bucket_size
  for slot = 0; slot < self.bucket_size; slot = slot + 1 {
    if self.buckets[base + slot] == fingerprint {
      self.buckets[base + slot] = b'\x00'
      return true
    }
  }
  false
}

///|
pub fn[K : Hash] CuckooFilter::insert(self : CuckooFilter, key : K) -> Bool {
  let (index1, fingerprint) = self.key_info(key)
  let index2 = self.alternate_index(index1, fingerprint)
  let empty1 = self.find_empty(index1)
  if empty1 >= 0 {
    self.buckets[index1 * self.bucket_size + empty1] = fingerprint
    self.inserted += 1
    return true
  }
  let empty2 = self.find_empty(index2)
  if empty2 >= 0 {
    self.buckets[index2 * self.bucket_size + empty2] = fingerprint
    self.inserted += 1
    return true
  }
  let evictions : Array[(Int32, Int32, Byte)] = []
  let mut index = index1
  let mut current = fingerprint
  for kick = 0; kick < 128; kick = kick + 1 {
    let empty = self.find_empty(index)
    if empty >= 0 {
      self.buckets[index * self.bucket_size + empty] = current
      self.inserted += 1
      return true
    }
    let slot = (current.to_int() + kick) % self.bucket_size
    let position = index * self.bucket_size + slot
    let displaced = self.buckets[position]
    evictions.push((index, slot, displaced))
    self.buckets[position] = current
    current = displaced
    index = self.alternate_index(index, current)
  }
  for i = evictions.length() - 1; i >= 0; i = i - 1 {
    let (bucket, slot, fingerprint) = evictions[i]
    self.buckets[bucket * self.bucket_size + slot] = fingerprint
  }
  false
}

///|
pub fn[K : Hash] CuckooFilter::contains(self : CuckooFilter, key : K) -> Bool {
  let (index1, fingerprint) = self.key_info(key)
  let index2 = self.alternate_index(index1, fingerprint)
  self.bucket_contains(index1, fingerprint) ||
  self.bucket_contains(index2, fingerprint)
}

///|
pub fn[K : Hash] CuckooFilter::remove(self : CuckooFilter, key : K) -> Bool {
  let (index1, fingerprint) = self.key_info(key)
  let index2 = self.alternate_index(index1, fingerprint)
  if self.bucket_remove(index1, fingerprint) ||
    self.bucket_remove(index2, fingerprint) {
    if self.inserted > 0 {
      self.inserted -= 1
    }
    true
  } else {
    false
  }
}

///|
pub fn[K : Hash] CuckooFilter::insert_all(
  self : CuckooFilter,
  keys : ArrayView[K],
) -> Bool {
  let mut inserted_all = true
  for key in keys {
    if !self.insert(key) {
      inserted_all = false
    }
  }
  inserted_all
}

///|
pub fn[K : Hash] CuckooFilter::contains_all(
  self : CuckooFilter,
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
pub fn[K : Hash] CuckooFilter::remove_all(
  self : CuckooFilter,
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
pub fn CuckooFilter::clear(self : CuckooFilter) -> Unit {
  for i = 0; i < self.buckets.length(); i = i + 1 {
    self.buckets[i] = b'\x00'
  }
  self.inserted = 0
}

///|
pub fn CuckooFilter::count(self : CuckooFilter) -> Int32 {
  self.inserted
}

///|
pub fn CuckooFilter::is_empty(self : CuckooFilter) -> Bool {
  self.inserted == 0
}

///|
pub fn CuckooFilter::bucket_count(self : CuckooFilter) -> Int32 {
  self.bucket_count
}

///|
pub fn CuckooFilter::bucket_size(self : CuckooFilter) -> Int32 {
  self.bucket_size
}
