///|
const SERIAL_MAGIC : UInt32 = 0x42464C54U

///|
const SERIAL_VERSION : Byte = b'\x01'

///|
const SERIAL_BLOOM : Byte = b'\x01'

///|
const SERIAL_COUNTING : Byte = b'\x02'

///|
const SERIAL_CUCKOO : Byte = b'\x03'

///|
const SERIAL_HEADER_BYTES : Int32 = 20

///|
fn serial_write_header(
  bytes : FixedArray[Byte],
  variant : Byte,
  first : Int32,
  second : Int32,
  third : Int32,
) -> Unit {
  bytes.unsafe_write_uint32_le(0, SERIAL_MAGIC)
  bytes[4] = variant
  bytes[5] = SERIAL_VERSION
  bytes[6] = b'\x00'
  bytes[7] = b'\x00'
  bytes.unsafe_write_uint32_le(8, first.reinterpret_as_uint())
  bytes.unsafe_write_uint32_le(12, second.reinterpret_as_uint())
  bytes.unsafe_write_uint32_le(16, third.reinterpret_as_uint())
}

///|
fn serial_read_header(data : Bytes, variant : Byte) -> (Int32, Int32, Int32) {
  guard data.length() >= SERIAL_HEADER_BYTES else {
    abort("serialized filter is too short")
  }
  guard data.unsafe_read_uint32_le(0) == SERIAL_MAGIC else {
    abort("invalid filter magic")
  }
  guard data.at(4) == variant && data.at(5) == SERIAL_VERSION else {
    abort("unsupported filter format")
  }
  guard data.at(6) == b'\x00' && data.at(7) == b'\x00' else {
    abort("unsupported filter format")
  }
  let first = data.unsafe_read_uint32_le(8).reinterpret_as_int()
  let second = data.unsafe_read_uint32_le(12).reinterpret_as_int()
  let third = data.unsafe_read_uint32_le(16).reinterpret_as_int()
  (first, second, third)
}

///|
fn serial_check_length(data : Bytes, expected : Int64) -> Unit {
  guard data.length().to_int64() == expected else {
    abort("serialized filter length mismatch")
  }
}

///|
/// Encode the filter as a portable byte sequence.
///
/// The encoding stores the configuration, insertion count, and bit array in a
/// versioned little-endian format. Hashing uses fixed seeds, so a filter can be
/// restored in another process and keep answering queries for the same keys.
pub fn BloomFilter::to_bytes(self : BloomFilter) -> Bytes {
  let word_count = self.words.length()
  let data = FixedArray::make(SERIAL_HEADER_BYTES + word_count * 8, b'\x00')
  serial_write_header(
    data,
    SERIAL_BLOOM,
    self.bit_count,
    self.hash_count,
    self.inserted,
  )
  for i = 0; i < word_count; i = i + 1 {
    data.unsafe_write_uint64_le(SERIAL_HEADER_BYTES + i * 8, self.words[i])
  }
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a filter produced by `BloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format version, or contains an
/// invalid configuration.
pub fn BloomFilter::from_bytes(data : Bytes) -> BloomFilter {
  let (bit_count, hash_count, inserted) = serial_read_header(data, SERIAL_BLOOM)
  guard bit_count > 0 && bit_count <= 2147483584 && bit_count % 64 == 0 else {
    abort("invalid bloom bit count")
  }
  guard hash_count > 0 else { abort("invalid bloom hash count") }
  guard inserted >= 0 else { abort("invalid bloom insertion count") }
  let word_count = bit_count / 64
  serial_check_length(
    data,
    SERIAL_HEADER_BYTES.to_int64() + word_count.to_int64() * 8L,
  )
  let words = FixedArray::make(word_count, 0UL)
  let mut set_bits = 0
  for i = 0; i < word_count; i = i + 1 {
    let word = data.unsafe_read_uint64_le(SERIAL_HEADER_BYTES + i * 8)
    words[i] = word
    set_bits = set_bits + word.popcnt()
  }
  guard set_bits.to_uint64() <= hash_count.to_uint64() * inserted.to_uint64() else {
    abort("bloom insertion count is too small for set bits")
  }
  { words, bit_count, hash_count, inserted, }
}

///|
/// Encode the counting filter as a portable byte sequence.
pub fn CountingBloomFilter::to_bytes(self : CountingBloomFilter) -> Bytes {
  let word_count = self.counters.length()
  let data = FixedArray::make(SERIAL_HEADER_BYTES + word_count * 8, b'\x00')
  serial_write_header(
    data,
    SERIAL_COUNTING,
    self.slot_count,
    self.hash_count,
    self.inserted,
  )
  for i = 0; i < word_count; i = i + 1 {
    data.unsafe_write_uint64_le(SERIAL_HEADER_BYTES + i * 8, self.counters[i])
  }
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a counting filter produced by `CountingBloomFilter::to_bytes`.
pub fn CountingBloomFilter::from_bytes(data : Bytes) -> CountingBloomFilter {
  let (slot_count, hash_count, inserted) = serial_read_header(
    data,
    SERIAL_COUNTING,
  )
  guard slot_count > 0 && slot_count <= 1073741808 && slot_count % 16 == 0 else {
    abort("invalid counting filter slot count")
  }
  guard hash_count > 0 else { abort("invalid counting filter hash count") }
  guard inserted >= 0 else { abort("invalid counting filter insertion count") }
  let word_count = slot_count / 4
  serial_check_length(
    data,
    SERIAL_HEADER_BYTES.to_int64() + word_count.to_int64() * 8L,
  )
  let counters = FixedArray::make(word_count, 0UL)
  let mut counter_mass = 0UL
  for i = 0; i < word_count; i = i + 1 {
    let word = data.unsafe_read_uint64_le(SERIAL_HEADER_BYTES + i * 8)
    counters[i] = word
    for lane = 0; lane < 4; lane = lane + 1 {
      counter_mass = counter_mass + ((word >> (lane * 16)) & 0xFFFFUL)
    }
  }
  guard counter_mass <= hash_count.to_uint64() * inserted.to_uint64() else {
    abort("counting insertion count is too small for positive counters")
  }
  { counters, slot_count, hash_count, inserted, }
}

///|
/// Encode the cuckoo filter as a portable byte sequence.
pub fn CuckooFilter::to_bytes(self : CuckooFilter) -> Bytes {
  let capacity = self.bucket_count * self.bucket_size
  let data = FixedArray::make(SERIAL_HEADER_BYTES + capacity, b'\x00')
  serial_write_header(
    data,
    SERIAL_CUCKOO,
    self.bucket_count,
    self.bucket_size,
    self.inserted,
  )
  for i = 0; i < capacity; i = i + 1 {
    data[SERIAL_HEADER_BYTES + i] = self.buckets[i]
  }
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a cuckoo filter produced by `CuckooFilter::to_bytes`.
pub fn CuckooFilter::from_bytes(data : Bytes) -> CuckooFilter {
  let (bucket_count, bucket_size, inserted) = serial_read_header(
    data,
    SERIAL_CUCKOO,
  )
  guard bucket_count > 0 &&
    bucket_count <= 1073741824 &&
    (bucket_count & (bucket_count - 1)) == 0 else {
    abort("invalid cuckoo bucket count")
  }
  guard bucket_size > 0 && bucket_size <= 2147483627 / bucket_count else {
    abort("invalid cuckoo bucket size")
  }
  let capacity = bucket_count * bucket_size
  guard inserted >= 0 && inserted <= capacity else {
    abort("invalid cuckoo insertion count")
  }
  serial_check_length(
    data,
    SERIAL_HEADER_BYTES.to_int64() + capacity.to_int64(),
  )
  let buckets = FixedArray::make(capacity, b'\x00')
  let mut stored = 0
  for i = 0; i < capacity; i = i + 1 {
    let fingerprint = data.at(SERIAL_HEADER_BYTES + i)
    buckets[i] = fingerprint
    if fingerprint != b'\x00' {
      stored = stored + 1
    }
  }
  guard stored == inserted else {
    abort("cuckoo insertion count does not match stored fingerprints")
  }
  let seed = (bucket_count.to_uint64() << 32) | bucket_size.to_uint64() | 1UL
  { buckets, bucket_count, bucket_size, inserted, random_state: mix64(seed), }
}
