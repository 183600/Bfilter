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
const SERIAL_SCALABLE : Byte = b'\x04'

///|
const SERIAL_COMPACT_COUNTING : Byte = b'\x05'

///|
const SERIAL_BLOCKED : Byte = b'\x06'

///|
const SERIAL_SCALABLE_COUNTING : Byte = b'\x07'

///|
const SERIAL_HEADER_BYTES : Int32 = 20

///|
/// Size of the target-rate field that follows the header of a scalable filter.
const SERIAL_RATE_BYTES : Int32 = 8

///|
/// Size of the metadata-entry count that follows the target rate of a
/// scalable counting filter.
const SERIAL_ENTRY_COUNT_BYTES : Int32 = 4

///|
/// Size of one tracked-key entry: two hashes, a slice index, and a
/// multiplicity.
const SERIAL_COUNTING_ENTRY_BYTES : Int32 = 24

///|
/// Size of the length prefix that precedes every serialized slice.
const SERIAL_SLICE_LENGTH_BYTES : Int32 = 4

///|
/// Number of bytes in one 64-bit word.
const SERIAL_BYTES_PER_WORD : Int32 = 8

///|
fn serial_write_header_at(
  bytes : FixedArray[Byte],
  offset : Int32,
  variant : Byte,
  first : Int32,
  second : Int32,
  third : Int32,
) -> Unit {
  bytes.unsafe_write_uint32_le(offset, SERIAL_MAGIC)
  bytes[offset + 4] = variant
  bytes[offset + 5] = SERIAL_VERSION
  bytes[offset + 6] = b'\x00'
  bytes[offset + 7] = b'\x00'
  bytes.unsafe_write_uint32_le(offset + 8, first.reinterpret_as_uint())
  bytes.unsafe_write_uint32_le(offset + 12, second.reinterpret_as_uint())
  bytes.unsafe_write_uint32_le(offset + 16, third.reinterpret_as_uint())
}

///|
fn serial_write_header(
  bytes : FixedArray[Byte],
  variant : Byte,
  first : Int32,
  second : Int32,
  third : Int32,
) -> Unit {
  serial_write_header_at(bytes, 0, variant, first, second, third)
}

///|
fn serial_read_header(data : BytesView, variant : Byte) -> (Int32, Int32, Int32) {
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
fn serial_check_length(data : BytesView, expected : Int64) -> Unit {
  guard data.length().to_int64() == expected else {
    abort("serialized filter length mismatch")
  }
}

///|
/// Total length of a serialized filter whose payload is `word_count` 64-bit
/// words.
fn serial_word_payload_bytes(word_count : Int32) -> Int64 {
  SERIAL_HEADER_BYTES.to_int64() +
  word_count.to_int64() * SERIAL_BYTES_PER_WORD.to_int64()
}

///|
/// Offset of the tracked-key table in a serialized scalable counting filter.
fn serial_counting_metadata_offset() -> Int32 {
  SERIAL_HEADER_BYTES + SERIAL_RATE_BYTES + SERIAL_ENTRY_COUNT_BYTES
}

///|
fn BloomFilter::serialized_size(self : BloomFilter) -> Int32 {
  SERIAL_HEADER_BYTES + self.words.length() * SERIAL_BYTES_PER_WORD
}

///|
fn BloomFilter::write_serialized(
  self : BloomFilter,
  data : FixedArray[Byte],
  offset : Int32,
) -> Unit {
  serial_write_header_at(
    data,
    offset,
    SERIAL_BLOOM,
    self.bit_count,
    self.hash_count,
    self.inserted,
  )
  let word_count = self.words.length()
  for i = 0; i < word_count; i = i + 1 {
    data.unsafe_write_uint64_le(
      offset + SERIAL_HEADER_BYTES + i * SERIAL_BYTES_PER_WORD,
      self.words[i],
    )
  }
}

///|
/// Encode the filter as a portable byte sequence.
///
/// The encoding stores the configuration, insertion count, and bit array in a
/// versioned little-endian format. Hashing uses fixed seeds, so a filter can be
/// restored in another process and keep answering queries for the same keys.
pub fn BloomFilter::to_bytes(self : BloomFilter) -> Bytes {
  let data = FixedArray::make(self.serialized_size(), b'\x00')
  self.write_serialized(data, 0)
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a Bloom filter from a byte view without copying the input first.
///
/// The decoded words are copied into a fresh backing array, so the returned
/// filter never retains the input view. Scalable decoders call this directly on
/// slice views to avoid an intermediate `to_owned()` copy per slice.
fn BloomFilter::read_serialized(data : BytesView) -> BloomFilter {
  let (bit_count, hash_count, inserted) = serial_read_header(data, SERIAL_BLOOM)
  guard bit_count > 0 &&
    bit_count <= BLOOM_MAX_BITS &&
    bit_count % WORD_BITS == 0 else {
    abort("invalid bloom bit count")
  }
  guard hash_count > 0 else { abort("invalid bloom hash count") }
  guard inserted >= 0 else { abort("invalid bloom insertion count") }
  let word_count = bit_count / WORD_BITS
  serial_check_length(
    data,
    serial_word_payload_bytes(word_count),
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
/// Decode a filter produced by `BloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format version, or contains an
/// invalid configuration.
pub fn BloomFilter::from_bytes(data : Bytes) -> BloomFilter {
  BloomFilter::read_serialized(data.exact_view())
}

///|
fn CountingBloomFilter::serialized_size(self : CountingBloomFilter) -> Int32 {
  SERIAL_HEADER_BYTES + self.counters.length() * SERIAL_BYTES_PER_WORD
}

///|
fn CountingBloomFilter::write_serialized(
  self : CountingBloomFilter,
  data : FixedArray[Byte],
  offset : Int32,
) -> Unit {
  serial_write_header_at(
    data,
    offset,
    SERIAL_COUNTING,
    self.slot_count,
    self.hash_count,
    self.inserted,
  )
  let word_count = self.counters.length()
  for i = 0; i < word_count; i = i + 1 {
    data.unsafe_write_uint64_le(
      offset + SERIAL_HEADER_BYTES + i * SERIAL_BYTES_PER_WORD,
      self.counters[i],
    )
  }
}

///|
/// Encode the counting filter as a portable byte sequence.
pub fn CountingBloomFilter::to_bytes(self : CountingBloomFilter) -> Bytes {
  let data = FixedArray::make(self.serialized_size(), b'\x00')
  self.write_serialized(data, 0)
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a counting filter from a byte view without copying the input first.
fn CountingBloomFilter::read_serialized(data : BytesView) -> CountingBloomFilter {
  let (slot_count, hash_count, inserted) = serial_read_header(
    data,
    SERIAL_COUNTING,
  )
  guard slot_count > 0 &&
    slot_count <= COUNTING_MAX_SLOTS &&
    slot_count % COUNTING_SLOTS_PER_WORD_ALIGN == 0 else {
    abort("invalid counting filter slot count")
  }
  guard hash_count > 0 else { abort("invalid counting filter hash count") }
  guard inserted >= 0 else { abort("invalid counting filter insertion count") }
  let word_count = slot_count / COUNTING_SLOTS_PER_WORD
  serial_check_length(
    data,
    serial_word_payload_bytes(word_count),
  )
  let counters = FixedArray::make(word_count, 0UL)
  let mut counter_mass = 0UL
  for i = 0; i < word_count; i = i + 1 {
    let word = data.unsafe_read_uint64_le(SERIAL_HEADER_BYTES + i * 8)
    counters[i] = word
    counter_mass = counter_mass + counting_word_mass(word)
  }
  guard counter_mass <= hash_count.to_uint64() * inserted.to_uint64() else {
    abort("counting insertion count is too small for positive counters")
  }
  let probe_length = counting_probe_length(hash_count, slot_count)
  {
    counters,
    slot_count,
    hash_count,
    inserted,
    counter_mass,
    probe_positions: FixedArray::make(probe_length, 0),
    probe_counts: FixedArray::make(probe_length, 0),
  }
}

///|
/// Decode a counting filter produced by `CountingBloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format version, or contains an
/// invalid configuration.
pub fn CountingBloomFilter::from_bytes(data : Bytes) -> CountingBloomFilter {
  CountingBloomFilter::read_serialized(data.exact_view())
}

///|
/// Trailing bytes that preserve the deterministic eviction state of a cuckoo
/// filter across a serialization round trip.
const CUCKOO_STATE_BYTES : Int32 = 8

///|
/// Encode the cuckoo filter as a portable byte sequence.
pub fn CuckooFilter::to_bytes(self : CuckooFilter) -> Bytes {
  let capacity = self.bucket_count * self.bucket_size
  let data = FixedArray::make(
    SERIAL_HEADER_BYTES + capacity + CUCKOO_STATE_BYTES,
    b'\x00',
  )
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
  data.unsafe_write_uint64_le(
    SERIAL_HEADER_BYTES + capacity,
    self.random_state,
  )
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a cuckoo filter produced by `CuckooFilter::to_bytes`.
pub fn CuckooFilter::from_bytes(data : Bytes) -> CuckooFilter {
  let (bucket_count, bucket_size, inserted) = serial_read_header(
    data.exact_view(),
    SERIAL_CUCKOO,
  )
  guard bucket_count > 0 &&
    bucket_count <= CUCKOO_MAX_BUCKETS &&
    (bucket_count & (bucket_count - 1)) == 0 else {
    abort("invalid cuckoo bucket count")
  }
  guard bucket_size > 0 && bucket_size <= CUCKOO_MAX_SLOTS / bucket_count else {
    abort("invalid cuckoo bucket size")
  }
  let capacity = bucket_count * bucket_size
  guard inserted >= 0 && inserted <= capacity else {
    abort("invalid cuckoo insertion count")
  }
  serial_check_length(
    data.exact_view(),
    SERIAL_HEADER_BYTES.to_int64() +
    capacity.to_int64() +
    CUCKOO_STATE_BYTES.to_int64(),
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
  let random_state = data.unsafe_read_uint64_le(
    SERIAL_HEADER_BYTES + capacity,
  )
  // A zero xorshift state is a fixed point, so every eviction would target the
  // same slot. Valid filters always seed a nonzero state and the xorshift is
  // invertible, so reject this malformed state instead of degrading placement.
  guard random_state != 0UL else {
    abort("invalid cuckoo eviction state")
  }
  { buckets, bucket_count, bucket_size, inserted, random_state, }
}

///|
/// Encode the scalable filter as a portable byte sequence.
///
/// The header stores the slice count, insertion count, initial capacity, and
/// target false-positive rate. Each slice is appended as a length-prefixed
/// Bloom filter produced by `BloomFilter::to_bytes`.
pub fn ScalableBloomFilter::to_bytes(self : ScalableBloomFilter) -> Bytes {
  // A zero-slice filter is a supported transient state for growth and set
  // operations, but the wire format requires at least one slice. Normalize it
  // to a single empty slice (carrying any conservative insertion count) before
  // encoding, so `to_bytes` never emits data that `from_bytes` rejects.
  if self.slices.length() == 0 {
    let normalized : ScalableBloomFilter = {
      slices: [],
      capacities: [],
      initial_capacity: self.initial_capacity,
      target_rate: self.target_rate,
      inserted: 0,
    }
    normalized.append_slice()
    normalized.slices[0].inserted = self.inserted
    normalized.inserted = self.inserted
    return normalized.to_bytes()
  }
  guard self.total_bits() <= BLOOM_MAX_BITS.to_int64() else {
    abort("scalable bloom filter is too large")
  }
  let mut total = SERIAL_HEADER_BYTES + SERIAL_RATE_BYTES
  for slice in self.slices {
    total = total + SERIAL_SLICE_LENGTH_BYTES + slice.serialized_size()
  }
  let data = FixedArray::make(total, b'\x00')
  serial_write_header(
    data,
    SERIAL_SCALABLE,
    self.slices.length(),
    self.inserted,
    self.initial_capacity,
  )
  data.unsafe_write_uint64_le(
    SERIAL_HEADER_BYTES,
    self.target_rate.reinterpret_as_uint64(),
  )
  let mut offset = SERIAL_HEADER_BYTES + SERIAL_RATE_BYTES
  for slice in self.slices {
    let slice_size = slice.serialized_size()
    data.unsafe_write_uint32_le(
      offset,
      slice_size.reinterpret_as_uint(),
    )
    offset = offset + SERIAL_SLICE_LENGTH_BYTES
    slice.write_serialized(data, offset)
    offset = offset + slice_size
  }
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a scalable filter produced by `ScalableBloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format, has an invalid target
/// rate or layout, or contains slices that do not match the growth policy.
pub fn ScalableBloomFilter::from_bytes(data : Bytes) -> ScalableBloomFilter {
  let (slice_count, inserted, initial_capacity) = serial_read_header(
    data.exact_view(),
    SERIAL_SCALABLE,
  )
  guard slice_count > 0 && slice_count <= 64 else {
    abort("invalid scalable bloom slice count")
  }
  guard initial_capacity > 0 else {
    abort("invalid scalable bloom initial capacity")
  }
  guard inserted >= 0 else { abort("invalid scalable bloom insertion count") }
  guard data.length() >= SERIAL_HEADER_BYTES + SERIAL_RATE_BYTES else {
    abort("serialized scalable bloom filter is too short")
  }
  let target_rate = data
    .unsafe_read_uint64_le(SERIAL_HEADER_BYTES)
    .reinterpret_as_double()
  guard target_rate > 0.0 && target_rate < 1.0 else {
    abort("invalid scalable bloom false positive rate")
  }
  let filter : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity,
    target_rate,
    inserted: 0,
  }
  let mut offset = SERIAL_HEADER_BYTES + SERIAL_RATE_BYTES
  let mut total_inserted = 0L
  let mut total_bits = 0L
  for index = 0; index < slice_count; index = index + 1 {
    guard offset <= data.length() - SERIAL_SLICE_LENGTH_BYTES else {
      abort("serialized scalable bloom slice is truncated")
    }
    let length = data.unsafe_read_uint32_le(offset).reinterpret_as_int()
    offset = offset + SERIAL_SLICE_LENGTH_BYTES
    guard length >= SERIAL_HEADER_BYTES && length <= data.length() - offset else {
      abort("serialized scalable bloom slice has invalid length")
    }
    let slice = BloomFilter::read_serialized(
      data.exact_view(start=offset, end=offset + length),
    )
    let capacity = if index == 0 {
      initial_capacity
    } else {
      let previous = filter.capacities[index - 1]
      if previous > MAX_INSERTIONS / SCALABLE_GROWTH {
        abort("scalable bloom filter is too large")
      }
      previous * SCALABLE_GROWTH
    }
    let (expected_bits, expected_hashes) = bloom_layout(
      capacity,
      scalable_slice_rate(target_rate, index),
    )
    guard slice.bit_count() == expected_bits &&
      slice.hash_count() == expected_hashes else {
      abort("scalable bloom slice does not match its layout")
    }
    total_bits = total_bits + slice.bit_count().to_int64()
    guard total_bits <= BLOOM_MAX_BITS.to_int64() else {
      abort("scalable bloom filter is too large")
    }
    total_inserted = total_inserted + slice.count().to_int64()
    filter.slices.push(slice)
    filter.capacities.push(capacity)
    offset = offset + length
  }
  guard offset == data.length() else {
    abort("serialized scalable bloom filter has trailing data")
  }
  guard total_inserted == inserted.to_int64() else {
    abort("scalable bloom insertion count does not match its slices")
  }
  filter.inserted = inserted
  filter
}

///|
/// Encode the scalable counting filter as a portable byte sequence.
///
/// The header stores the slice count, insertion count, initial capacity, and
/// target false-positive rate. A table of tracked key hashes records the owning
/// slice and exact multiplicity for every distinct key, followed by each slice
/// as a length-prefixed `CountingBloomFilter` byte sequence.
pub fn ScalableCountingBloomFilter::to_bytes(
  self : ScalableCountingBloomFilter,
) -> Bytes {
  // The wire format requires at least one slice. A zero-slice filter is a
  // supported transient state, so encode it as one empty slice with the same
  // conservative insertion count instead of producing unreadable bytes.
  if self.slices.length() == 0 {
    let normalized : ScalableCountingBloomFilter = {
      slices: [],
      capacities: [],
      locations: @hashmap.HashMap([]),
      initial_capacity: self.initial_capacity,
      target_rate: self.target_rate,
      inserted: 0,
    }
    normalized.append_slice()
    normalized.slices[0].inserted = self.inserted
    normalized.inserted = self.inserted
    return normalized.to_bytes()
  }
  guard self.slot_count() <= SCALABLE_COUNTING_MAX_SLOTS else {
    abort("scalable counting bloom filter is too large")
  }
  let mut total = serial_counting_metadata_offset()
  for slice in self.slices {
    total = total + SERIAL_SLICE_LENGTH_BYTES + slice.serialized_size()
  }
  let entry_count = self.locations.length()
  guard entry_count >= 0 &&
    entry_count <= (MAX_INSERTIONS - total) / SERIAL_COUNTING_ENTRY_BYTES else {
    abort("scalable counting bloom filter is too large to serialize")
  }
  total = total + entry_count * SERIAL_COUNTING_ENTRY_BYTES
  let data = FixedArray::make(total, b'\x00')
  serial_write_header(
    data,
    SERIAL_SCALABLE_COUNTING,
    self.slices.length(),
    self.inserted,
    self.initial_capacity,
  )
  data.unsafe_write_uint64_le(
    SERIAL_HEADER_BYTES,
    self.target_rate.reinterpret_as_uint64(),
  )
  data.unsafe_write_uint32_le(
    SERIAL_HEADER_BYTES + SERIAL_RATE_BYTES,
    entry_count.reinterpret_as_uint(),
  )
  let entries = self.locations.to_array()
  entries.sort()
  let mut offset = serial_counting_metadata_offset()
  for entry in entries {
    let ((h1, h2), (slice_index, occurrences)) = entry
    data.unsafe_write_uint64_le(offset, h1)
    data.unsafe_write_uint64_le(offset + 8, h2)
    data.unsafe_write_uint32_le(
      offset + 16,
      slice_index.reinterpret_as_uint(),
    )
    data.unsafe_write_uint32_le(
      offset + 20,
      occurrences.reinterpret_as_uint(),
    )
    offset = offset + SERIAL_COUNTING_ENTRY_BYTES
  }
  for slice in self.slices {
    let slice_size = slice.serialized_size()
    data.unsafe_write_uint32_le(
      offset,
      slice_size.reinterpret_as_uint(),
    )
    offset = offset + SERIAL_SLICE_LENGTH_BYTES
    slice.write_serialized(data, offset)
    offset = offset + slice_size
  }
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a scalable counting filter produced by
/// `ScalableCountingBloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format, has an invalid target
/// rate, contains slices that do not match the growth policy, or has metadata
/// that points outside the decoded slices.
pub fn ScalableCountingBloomFilter::from_bytes(
  data : Bytes,
) -> ScalableCountingBloomFilter {
  let (slice_count, inserted, initial_capacity) = serial_read_header(
    data.exact_view(),
    SERIAL_SCALABLE_COUNTING,
  )
  guard slice_count > 0 && slice_count <= 64 else {
    abort("invalid scalable counting bloom slice count")
  }
  guard initial_capacity > 0 else {
    abort("invalid scalable counting bloom initial capacity")
  }
  guard inserted >= 0 else {
    abort("invalid scalable counting bloom insertion count")
  }
  guard data.length() >= serial_counting_metadata_offset() else {
    abort("serialized scalable counting bloom filter is too short")
  }
  let target_rate = data
    .unsafe_read_uint64_le(SERIAL_HEADER_BYTES)
    .reinterpret_as_double()
  guard target_rate > 0.0 && target_rate < 1.0 else {
    abort("invalid scalable counting bloom false positive rate")
  }
  let entry_count = data
    .unsafe_read_uint32_le(SERIAL_HEADER_BYTES + SERIAL_RATE_BYTES)
    .reinterpret_as_int()
  guard entry_count >= 0 && entry_count <= inserted else {
    abort("invalid scalable counting bloom metadata count")
  }
  let metadata_offset = serial_counting_metadata_offset()
  guard entry_count <=
    (data.length() - metadata_offset) / SERIAL_COUNTING_ENTRY_BYTES else {
    abort("serialized scalable counting bloom metadata is truncated")
  }
  let slices_offset = metadata_offset + entry_count *
    SERIAL_COUNTING_ENTRY_BYTES
  let filter : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([], capacity=entry_count),
    initial_capacity,
    target_rate,
    inserted: 0,
  }
  let mut offset = slices_offset
  let mut total_inserted = 0L
  let mut total_slots = 0L
  for index = 0; index < slice_count; index = index + 1 {
    guard offset <= data.length() - SERIAL_SLICE_LENGTH_BYTES else {
      abort("serialized scalable counting bloom slice is truncated")
    }
    let length = data.unsafe_read_uint32_le(offset).reinterpret_as_int()
    offset = offset + SERIAL_SLICE_LENGTH_BYTES
    guard length >= SERIAL_HEADER_BYTES && length <= data.length() - offset else {
      abort("serialized scalable counting bloom slice has invalid length")
    }
    let slice = CountingBloomFilter::read_serialized(
      data.exact_view(start=offset, end=offset + length),
    )
    let capacity = if index == 0 {
      initial_capacity
    } else {
      let previous = filter.capacities[index - 1]
      if previous > MAX_INSERTIONS / SCALABLE_GROWTH {
        abort("scalable counting bloom filter is too large")
      }
      previous * SCALABLE_GROWTH
    }
    let (expected_slots, expected_hashes) = counting_bloom_layout(
      capacity,
      scalable_counting_slice_rate(target_rate, index),
    )
    guard slice.slot_count() == expected_slots &&
      slice.hash_count() == expected_hashes else {
      abort("scalable counting bloom slice does not match its layout")
    }
    total_slots = total_slots + slice.slot_count().to_int64()
    guard total_slots <= SCALABLE_COUNTING_MAX_SLOTS else {
      abort("scalable counting bloom filter is too large")
    }
    total_inserted = total_inserted + slice.count().to_int64()
    filter.slices.push(slice)
    filter.capacities.push(capacity)
    offset = offset + length
  }
  guard offset == data.length() else {
    abort("serialized scalable counting bloom filter has trailing data")
  }
  guard total_inserted == inserted.to_int64() else {
    abort("scalable counting bloom insertion count does not match its slices")
  }
  let slice_occurrences : Array[Int64] = Array::make(slice_count, 0L)
  offset = metadata_offset
  let mut total_occurrences = 0L
  for entry = 0; entry < entry_count; entry = entry + 1 {
    let h1 = data.unsafe_read_uint64_le(offset)
    let h2 = data.unsafe_read_uint64_le(offset + 8)
    let slice_index = data
      .unsafe_read_uint32_le(offset + 16)
      .reinterpret_as_int()
    let occurrences = data
      .unsafe_read_uint32_le(offset + 20)
      .reinterpret_as_int()
    guard slice_index >= 0 && slice_index < slice_count else {
      abort("scalable counting bloom metadata points outside its slices")
    }
    guard occurrences > 0 else {
      abort("invalid scalable counting bloom occurrence count")
    }
    let slice_total = slice_occurrences[slice_index] + occurrences.to_int64()
    guard slice_total <= filter.slices[slice_index].count().to_int64() else {
      abort("scalable counting bloom metadata exceeds its slice count")
    }
    slice_occurrences[slice_index] = slice_total
    total_occurrences = total_occurrences + occurrences.to_int64()
    guard total_occurrences <= inserted.to_int64() else {
      abort("invalid scalable counting bloom occurrence count")
    }
    let id = (h1, h2)
    let previous_length = filter.locations.length()
    filter.locations.set(id, (slice_index, occurrences))
    guard filter.locations.length() == previous_length + 1 else {
      abort("duplicate scalable counting bloom metadata entry")
    }
    offset = offset + SERIAL_COUNTING_ENTRY_BYTES
  }
  if total_occurrences != inserted.to_int64() {
    // Slices without tracked keys may carry conservative count-only insertions.
    // A slice that does track keys, however, must have an insertion count equal
    // to its tracked occurrences, and an untracked slice may not hide positive
    // counters. This accepts a count-only filter that later gained tracked keys
    // while still rejecting metadata that was lost or truncated.
    for i = 0; i < slice_count; i = i + 1 {
      if slice_occurrences[i] > 0L {
        guard slice_occurrences[i] == filter.slices[i].count().to_int64() else {
          abort(
            "scalable counting bloom metadata does not match its insertion count",
          )
        }
      } else {
        guard filter.slices[i].occupied_slot_count() == 0 else {
          abort(
            "scalable counting bloom metadata does not match its insertion count",
          )
        }
      }
    }
  }
  filter.inserted = inserted
  filter
}

///|
/// Encode the compact counting filter as a portable byte sequence.
pub fn CompactCountingBloomFilter::to_bytes(
  self : CompactCountingBloomFilter,
) -> Bytes {
  let word_count = self.counters.length()
  let data = FixedArray::make(
    SERIAL_HEADER_BYTES + word_count * SERIAL_BYTES_PER_WORD,
    b'\x00',
  )
  serial_write_header(
    data,
    SERIAL_COMPACT_COUNTING,
    self.slot_count,
    self.hash_count,
    self.inserted,
  )
  for i = 0; i < word_count; i = i + 1 {
    data.unsafe_write_uint64_le(
      SERIAL_HEADER_BYTES + i * SERIAL_BYTES_PER_WORD,
      self.counters[i],
    )
  }
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a compact counting filter produced by
/// `CompactCountingBloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format version, or contains an
/// invalid configuration.
pub fn CompactCountingBloomFilter::from_bytes(
  data : Bytes,
) -> CompactCountingBloomFilter {
  let (slot_count, hash_count, inserted) = serial_read_header(
    data.exact_view(),
    SERIAL_COMPACT_COUNTING,
  )
  guard slot_count > 0 &&
    slot_count <= COMPACT_MAX_SLOTS &&
    slot_count % COMPACT_SLOTS_PER_WORD == 0 else {
    abort("invalid compact counting filter slot count")
  }
  guard hash_count > 0 else {
    abort("invalid compact counting filter hash count")
  }
  guard inserted >= 0 else {
    abort("invalid compact counting filter insertion count")
  }
  let word_count = slot_count / COMPACT_SLOTS_PER_WORD
  serial_check_length(
    data.exact_view(),
    serial_word_payload_bytes(word_count),
  )
  let counters = FixedArray::make(word_count, 0UL)
  let mut counter_mass = 0UL
  for i = 0; i < word_count; i = i + 1 {
    let word = data.unsafe_read_uint64_le(SERIAL_HEADER_BYTES + i * 8)
    counters[i] = word
    counter_mass = counter_mass + compact_word_mass(word)
  }
  guard counter_mass <= hash_count.to_uint64() * inserted.to_uint64() else {
    abort("compact counting insertion count is too small for positive counters")
  }
  let probe_length = counting_probe_length(hash_count, slot_count)
  {
    counters,
    slot_count,
    hash_count,
    inserted,
    counter_mass,
    probe_positions: FixedArray::make(probe_length, 0),
    probe_counts: FixedArray::make(probe_length, 0),
  }
}

///|
/// Encode the blocked filter as a portable byte sequence.
pub fn BlockedBloomFilter::to_bytes(self : BlockedBloomFilter) -> Bytes {
  let word_count = self.words.length()
  let data = FixedArray::make(
    SERIAL_HEADER_BYTES + word_count * SERIAL_BYTES_PER_WORD,
    b'\x00',
  )
  serial_write_header(
    data,
    SERIAL_BLOCKED,
    self.bit_count,
    self.hash_count,
    self.inserted,
  )
  for i = 0; i < word_count; i = i + 1 {
    data.unsafe_write_uint64_le(
      SERIAL_HEADER_BYTES + i * SERIAL_BYTES_PER_WORD,
      self.words[i],
    )
  }
  Bytes::from_array(data.exact_view())
}

///|
/// Decode a blocked filter produced by `BlockedBloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format version, or contains an
/// invalid configuration.
pub fn BlockedBloomFilter::from_bytes(data : Bytes) -> BlockedBloomFilter {
  let (bit_count, hash_count, inserted) = serial_read_header(
    data.exact_view(),
    SERIAL_BLOCKED,
  )
  guard bit_count > 0 &&
    bit_count <= BLOCKED_MAX_BITS &&
    bit_count % BLOCKED_BLOCK_BITS == 0 else {
    abort("invalid blocked bloom bit count")
  }
  guard hash_count > 0 else { abort("invalid blocked bloom hash count") }
  guard inserted >= 0 else { abort("invalid blocked bloom insertion count") }
  let word_count = bit_count / WORD_BITS
  serial_check_length(
    data,
    serial_word_payload_bytes(word_count),
  )
  let words = FixedArray::make(word_count, 0UL)
  let mut set_bits = 0
  let mut nonempty_blocks = 0
  let mut block_has_bit = false
  for i = 0; i < word_count; i = i + 1 {
    let word = data.unsafe_read_uint64_le(SERIAL_HEADER_BYTES + i * 8)
    words[i] = word
    set_bits = set_bits + word.popcnt()
    if word != 0UL {
      block_has_bit = true
    }
    if i % BLOCKED_BLOCK_WORDS == BLOCKED_BLOCK_WORDS - 1 {
      if block_has_bit {
        nonempty_blocks = nonempty_blocks + 1
      }
      block_has_bit = false
    }
  }
  // One insertion probes at most one 512-bit block, so it can set at most
  // `min(hash_count, 512)` bits and can make at most one additional block
  // nonempty. Reject encodings that no insertion history can produce.
  let probes_per_insertion = if hash_count < BLOCKED_BLOCK_BITS {
    hash_count
  } else {
    BLOCKED_BLOCK_BITS
  }
  guard set_bits.to_uint64() <=
    probes_per_insertion.to_uint64() * inserted.to_uint64() else {
    abort("blocked bloom insertion count is too small for set bits")
  }
  guard nonempty_blocks <= inserted else {
    abort("blocked bloom insertion count is too small for nonempty blocks")
  }
  { words, bit_count, hash_count, inserted, }
}
