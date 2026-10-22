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
fn BloomFilter::serialized_size(self : BloomFilter) -> Int32 {
  SERIAL_HEADER_BYTES + self.words.length() * 8
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
      offset + SERIAL_HEADER_BYTES + i * 8,
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
fn CountingBloomFilter::serialized_size(self : CountingBloomFilter) -> Int32 {
  SERIAL_HEADER_BYTES + self.counters.length() * 8
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
      offset + SERIAL_HEADER_BYTES + i * 8,
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

///|
/// Encode the scalable filter as a portable byte sequence.
///
/// The header stores the slice count, insertion count, initial capacity, and
/// target false-positive rate. Each slice is appended as a length-prefixed
/// Bloom filter produced by `BloomFilter::to_bytes`.
pub fn ScalableBloomFilter::to_bytes(self : ScalableBloomFilter) -> Bytes {
  let mut total = SERIAL_HEADER_BYTES + 8
  for slice in self.slices {
    total = total + 4 + slice.serialized_size()
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
  let mut offset = SERIAL_HEADER_BYTES + 8
  for slice in self.slices {
    data.unsafe_write_uint32_le(
      offset,
      slice.serialized_size().reinterpret_as_uint(),
    )
    offset = offset + 4
    slice.write_serialized(data, offset)
    offset = offset + slice.serialized_size()
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
    data,
    SERIAL_SCALABLE,
  )
  guard slice_count > 0 && slice_count <= 64 else {
    abort("invalid scalable bloom slice count")
  }
  guard initial_capacity > 0 else {
    abort("invalid scalable bloom initial capacity")
  }
  guard inserted >= 0 else { abort("invalid scalable bloom insertion count") }
  guard data.length() >= SERIAL_HEADER_BYTES + 8 else {
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
  let mut offset = SERIAL_HEADER_BYTES + 8
  let mut total_inserted = 0L
  let mut total_bits = 0L
  for index = 0; index < slice_count; index = index + 1 {
    guard offset <= data.length() - 4 else {
      abort("serialized scalable bloom slice is truncated")
    }
    let length = data.unsafe_read_uint32_le(offset).reinterpret_as_int()
    offset = offset + 4
    guard length >= SERIAL_HEADER_BYTES && length <= data.length() - offset else {
      abort("serialized scalable bloom slice has invalid length")
    }
    let slice = BloomFilter::from_bytes(
      data.exact_view(start=offset, end=offset + length).to_owned(),
    )
    let capacity = if index == 0 {
      initial_capacity
    } else {
      let previous = filter.capacities[index - 1]
      if previous > 2147483647 / SCALABLE_GROWTH {
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
    guard total_bits <= 2147483584L else {
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
  let mut total = SERIAL_HEADER_BYTES + 12
  for slice in self.slices {
    total = total + 4 + slice.serialized_size()
  }
  let entry_count = self.locations.length()
  guard entry_count >= 0 && entry_count <= (2147483647 - total) / 24 else {
    abort("scalable counting bloom filter is too large to serialize")
  }
  total = total + entry_count * 24
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
    SERIAL_HEADER_BYTES + 8,
    entry_count.reinterpret_as_uint(),
  )
  let entries : Array[((UInt64, UInt64), (Int32, Int32))] = []
  for entry in self.locations.iter() {
    entries.push(entry)
  }
  entries.sort_by(fn(left, right) {
    let ((left_h1, left_h2), _) = left
    let ((right_h1, right_h2), _) = right
    if left_h1 < right_h1 {
      -1
    } else if left_h1 > right_h1 {
      1
    } else if left_h2 < right_h2 {
      -1
    } else if left_h2 > right_h2 {
      1
    } else {
      0
    }
  })
  let mut offset = SERIAL_HEADER_BYTES + 12
  for entry in entries {
    let ((h1, h2), (slice_index, occurrences)) = entry
    data.unsafe_write_uint64_le(offset, h1)
    data.unsafe_write_uint64_le(offset + 8, h2)
    data.unsafe_write_uint32_le(offset + 16, slice_index.reinterpret_as_uint())
    data.unsafe_write_uint32_le(offset + 20, occurrences.reinterpret_as_uint())
    offset = offset + 24
  }
  for slice in self.slices {
    data.unsafe_write_uint32_le(
      offset,
      slice.serialized_size().reinterpret_as_uint(),
    )
    offset = offset + 4
    slice.write_serialized(data, offset)
    offset = offset + slice.serialized_size()
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
    data,
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
  guard data.length() >= SERIAL_HEADER_BYTES + 12 else {
    abort("serialized scalable counting bloom filter is too short")
  }
  let target_rate = data
    .unsafe_read_uint64_le(SERIAL_HEADER_BYTES)
    .reinterpret_as_double()
  guard target_rate > 0.0 && target_rate < 1.0 else {
    abort("invalid scalable counting bloom false positive rate")
  }
  let entry_count = data
    .unsafe_read_uint32_le(SERIAL_HEADER_BYTES + 8)
    .reinterpret_as_int()
  guard entry_count >= 0 && entry_count <= inserted else {
    abort("invalid scalable counting bloom metadata count")
  }
  let metadata_offset = SERIAL_HEADER_BYTES + 12
  guard entry_count <= (data.length() - metadata_offset) / 24 else {
    abort("serialized scalable counting bloom metadata is truncated")
  }
  let slices_offset = metadata_offset + entry_count * 24
  let filter : ScalableCountingBloomFilter = {
    slices: [],
    capacities: [],
    locations: @hashmap.HashMap([]),
    initial_capacity,
    target_rate,
    inserted: 0,
  }
  let mut offset = slices_offset
  let mut total_inserted = 0L
  let mut total_slots = 0L
  for index = 0; index < slice_count; index = index + 1 {
    guard offset <= data.length() - 4 else {
      abort("serialized scalable counting bloom slice is truncated")
    }
    let length = data.unsafe_read_uint32_le(offset).reinterpret_as_int()
    offset = offset + 4
    guard length >= SERIAL_HEADER_BYTES && length <= data.length() - offset else {
      abort("serialized scalable counting bloom slice has invalid length")
    }
    let slice = CountingBloomFilter::from_bytes(
      data.exact_view(start=offset, end=offset + length).to_owned(),
    )
    let capacity = if index == 0 {
      initial_capacity
    } else {
      let previous = filter.capacities[index - 1]
      if previous > 2147483647 / SCALABLE_COUNTING_GROWTH {
        abort("scalable counting bloom filter is too large")
      }
      previous * SCALABLE_COUNTING_GROWTH
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
    guard !filter.locations.contains(id) else {
      abort("duplicate scalable counting bloom metadata entry")
    }
    filter.locations.set(id, (slice_index, occurrences))
    offset = offset + 24
  }
  if total_occurrences != inserted.to_int64() {
    // A count-only filter can carry a conservative insertion count in its
    // slices without tracking any key. This form has no metadata and no
    // positive counters, so it cannot hide a lost tracked occurrence. A
    // filter with positive counters but no metadata, on the other hand, is
    // inconsistent and must still be rejected.
    let count_only_state = entry_count == 0 && filter.occupied_slot_count() == 0L
    guard count_only_state else {
      abort(
        "scalable counting bloom metadata does not match its insertion count",
      )
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
  let data = FixedArray::make(SERIAL_HEADER_BYTES + word_count * 8, b'\x00')
  serial_write_header(
    data,
    SERIAL_COMPACT_COUNTING,
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
/// Decode a compact counting filter produced by
/// `CompactCountingBloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format version, or contains an
/// invalid configuration.
pub fn CompactCountingBloomFilter::from_bytes(
  data : Bytes,
) -> CompactCountingBloomFilter {
  let (slot_count, hash_count, inserted) = serial_read_header(
    data,
    SERIAL_COMPACT_COUNTING,
  )
  guard slot_count > 0 && slot_count <= 1073741808 && slot_count % 16 == 0 else {
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
    data,
    SERIAL_HEADER_BYTES.to_int64() + word_count.to_int64() * 8L,
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
  let data = FixedArray::make(SERIAL_HEADER_BYTES + word_count * 8, b'\x00')
  serial_write_header(
    data,
    SERIAL_BLOCKED,
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
/// Decode a blocked filter produced by `BlockedBloomFilter::to_bytes`.
///
/// Panics if the data is truncated, uses another format version, or contains an
/// invalid configuration.
pub fn BlockedBloomFilter::from_bytes(data : Bytes) -> BlockedBloomFilter {
  let (bit_count, hash_count, inserted) = serial_read_header(
    data,
    SERIAL_BLOCKED,
  )
  guard bit_count > 0 &&
    bit_count <= BLOCKED_MAX_BITS &&
    bit_count % BLOCKED_BLOCK_BITS == 0 else {
    abort("invalid blocked bloom bit count")
  }
  guard hash_count > 0 else { abort("invalid blocked bloom hash count") }
  guard inserted >= 0 else { abort("invalid blocked bloom insertion count") }
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
    abort("blocked bloom insertion count is too small for set bits")
  }
  { words, bit_count, hash_count, inserted, }
}
