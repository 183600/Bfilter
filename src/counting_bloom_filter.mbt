///|
/// A Bloom filter variant that stores a counter per slot, enabling deletion.
///
/// Counters are packed four per `UInt64` as 16-bit values, so each slot costs
/// two bytes. A counter saturates at 65535 instead of wrapping; removing a key
/// that was never inserted can still corrupt the filter when it produces a
/// false positive, which is inherent to counting Bloom filters.
pub struct CountingBloomFilter {
  priv counters : FixedArray[UInt64]
  priv slot_count : Int32
  priv hash_count : Int32
  priv mut inserted : Int32
  priv mut counter_mass : UInt64
  // Reusable probe buffers make inserts and removals allocation-free without
  // changing the observable state. They stay empty for very wide layouts so a
  // large nominal hash count does not reserve scratch memory up front.
  priv probe_positions : FixedArray[Int32]
  priv probe_counts : FixedArray[Int32]
}

///|
/// Mark the high bit of every 16-bit lane whose counter is positive.
///
/// The low 15 bits of each lane are shifted into the high bit without carrying
/// into the next lane, so a bitwise AND of two masks identifies slots that are
/// positive in both filters.
fn counting_nonzero_lanes(word : UInt64) -> UInt64 {
  let low = word & 0x7FFF7FFF7FFF7FFFUL
  ((low + 0x7FFF7FFF7FFF7FFFUL) | (word & 0x8000800080008000UL)) &
  0x8000800080008000UL
}

///|
/// Sum the four 16-bit counters packed into a word.
fn counting_word_mass(word : UInt64) -> UInt64 {
  let low = word & 0x0000FFFF0000FFFFUL
  let high = (word >> 16) & 0x0000FFFF0000FFFFUL
  let pairs = low + high
  (pairs & 0x00000000FFFFFFFFUL) + ((pairs >> 32) & 0x00000000FFFFFFFFUL)
}

///|
/// High bit of every 16-bit counter lane.
const COUNTING_LANE_SIGN : UInt64 = 0x8000800080008000UL

///|
/// Low fifteen bits of every 16-bit counter lane.
const COUNTING_LANE_LOW : UInt64 = 0x7FFF7FFF7FFF7FFFUL

///|
/// Largest multiple of `occurrences` that fits in a 16-bit counter.
///
/// When one counter is selected several times by the same key, capping at a
/// multiple of that count keeps every removal able to subtract a full
/// contribution instead of leaving a residue below the required amount.
fn counting_position_limit(occurrences : UInt64) -> UInt64 {
  if occurrences > 0xFFFFUL {
    0xFFFFUL
  } else {
    0xFFFFUL - 0xFFFFUL % occurrences
  }
}

///|
/// Mark the high bit of every lane where `left` is at least `right`.
///
/// Forcing the high bit of `left` and clearing it in `right` keeps the
/// subtraction inside each lane, so a borrow never crosses lane boundaries. The
/// high bit of the difference is then set exactly for lanes whose low fifteen
/// bits satisfy `left >= right`; lanes whose high bits differ are decided by
/// those high bits instead.
fn counting_lane_at_least(left : UInt64, right : UInt64) -> UInt64 {
  let different = (left ^ right) & COUNTING_LANE_SIGN
  let left_sign = left & COUNTING_LANE_SIGN
  let low_at_least = ((left | COUNTING_LANE_SIGN) - (right & COUNTING_LANE_LOW)) &
    COUNTING_LANE_SIGN
  (different & left_sign) | ((COUNTING_LANE_SIGN ^ different) & low_at_least)
}

///|
/// Take the larger of the two counters in every 16-bit lane.
fn counting_lane_max(left : UInt64, right : UInt64) -> UInt64 {
  let at_least = counting_lane_at_least(left, right)
  let lanes = (at_least >> 15) * 0xFFFFUL
  right ^ ((left ^ right) & lanes)
}

///|
/// Take the smaller of the two counters in every 16-bit lane.
fn counting_lane_min(left : UInt64, right : UInt64) -> UInt64 {
  left ^ right ^ counting_lane_max(left, right)
}

///|
/// Compute the slot and hash layout used by counting filters.
fn counting_bloom_layout(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  let n = expected_items.to_double()
  let ln2 = 0.6931471805599453
  let bits = -(n * @math.ln(false_positive_rate)) / (ln2 * ln2)
  guard bits <= 2147483584.0 else { abort("bloom filter size is too large") }
  let slot_count = (bits.ceil().to_int() + 15) / 16 * 16
  guard slot_count <= 1073741808 else {
    abort("counting bloom filter size is too large")
  }
  let hash_count = (bits / n * ln2).round().to_int().max(1)
  (slot_count, hash_count)
}

///|
/// Largest value a single 16-bit counter can hold.
pub fn CountingBloomFilter::counter_max() -> Int32 {
  0xFFFF
}

///|
/// Compute the slot and hash counts that `CountingBloomFilter::new` would use.
///
/// The returned slot count is already rounded up to a multiple of 16, so it
/// matches `slot_count()` on a filter built with the same arguments. Panics for
/// the same invalid arguments as `CountingBloomFilter::new`.
pub fn CountingBloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
  counting_bloom_layout(expected_items, false_positive_rate)
}

///|
/// Create a counting filter sized for `expected_items` and the target
/// `false_positive_rate`.
///
/// Panics if `expected_items` is not positive, the rate is not in `(0, 1)`, or
/// the requested filter would exceed the supported size.
pub fn CountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> CountingBloomFilter {
  let (slot_count, hash_count) = CountingBloomFilter::optimal_size(
    expected_items, false_positive_rate,
  )
  CountingBloomFilter::with_size(slot_count, hash_count)
}

///|
/// Create a counting filter with an explicit slot and hash count.
///
/// `slot_count` is rounded up to a multiple of 16 so counters pack evenly into
/// `UInt64` words.
pub fn CountingBloomFilter::with_size(
  slot_count : Int32,
  hash_count : Int32,
) -> CountingBloomFilter {
  guard slot_count > 0 && slot_count <= 1073741808 else {
    abort("slot_count must be positive and not too large")
  }
  guard hash_count > 0 else { abort("hash_count must be positive") }
  let rounded = (slot_count + 15) / 16 * 16
  let probe_length = counting_probe_length(hash_count, rounded)
  {
    counters: FixedArray::make(rounded / 4, 0UL),
    slot_count: rounded,
    hash_count,
    inserted: 0,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(probe_length, 0),
    probe_counts: FixedArray::make(probe_length, 0),
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
  let value = if value > 0xFFFFUL { 0xFFFFUL } else { value }
  let old = (self.counters[word] >> shift) & 0xFFFFUL
  let cleared = self.counters[word] ^ (old << shift)
  self.counters[word] = cleared | (value << shift)
  self.counter_mass = self.counter_mass - old + value
}

///|
/// The distinct slots selected by one key and how often each is selected.
///
/// Both arrays hold at most `min(hash_count, slot_count)` entries and only
/// their first `length` entries are meaningful. Keeping the pairs in two packed
/// arrays avoids allocating one tuple per probe on every insert or removal.
priv struct CountingPositionSet {
  positions : FixedArray[Int32]
  counts : FixedArray[Int32]
  length : Int32
}

///|
/// Largest hash count that receives reusable probe buffers.
///
/// The buffers are only a workspace and do not affect the serialized layout.
/// Capping them keeps a filter with an unusually wide, but still valid, hash
/// count from reserving permanent scratch memory it may never need.
const COUNTING_PROBE_SCRATCH_LIMIT : Int32 = 1024

///|
/// Length of the reusable probe workspace for a filter layout.
///
/// A key can select at most one distinct position per slot, so a small slot
/// count caps the number of meaningful entries even when the hash count is
/// wide. Layouts with an unusually wide hash count still skip the permanent
/// workspace and allocate a temporary set for each operation.
fn counting_probe_length(hash_count : Int32, slot_count : Int32) -> Int32 {
  if hash_count > COUNTING_PROBE_SCRATCH_LIMIT {
    0
  } else if hash_count < slot_count {
    hash_count
  } else {
    slot_count
  }
}

///|
/// Compute each distinct slot selected by a key together with the number of
/// hash functions that select it.
///
/// Small filters deduplicate in place with a quadratic scan over at most 64
/// probes; filters with many hash functions switch to a hash map so duplicate
/// detection stays linear instead of rescanning every previously seen position.
///
/// The caller supplies the result arrays so hot paths can reuse a per-filter
/// workspace. Their length must be at least `min(hash_count, slot_count)`,
/// because a key cannot select more distinct slots than the filter holds.
fn unique_key_positions_into(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : UInt64,
  positions : FixedArray[Int32],
  counts : FixedArray[Int32],
) -> Int32 {
  let mut length = 0
  let mut state = h1
  if hash_count <= 64 {
    for i = 0; i < hash_count; i = i + 1 {
      let position = (state % slot_count).to_int()
      let mut found = -1
      for j = 0; j < length; j = j + 1 {
        if positions[j] == position {
          found = j
          break
        }
      }
      if found >= 0 {
        counts[found] = counts[found] + 1
      } else {
        positions[length] = position
        counts[length] = 1
        length = length + 1
      }
      state = state + h2
    }
  } else {
    let occurrences : @hashmap.HashMap[Int32, Int32] = @hashmap.HashMap([])
    for i = 0; i < hash_count; i = i + 1 {
      let position = (state % slot_count).to_int()
      match occurrences.get(position) {
        Some(count) => occurrences.set(position, count + 1)
        None => occurrences.set(position, 1)
      }
      state = state + h2
    }
    for entry in occurrences.iter() {
      let (position, count) = entry
      positions[length] = position
      counts[length] = count
      length = length + 1
    }
  }
  length
}

///|
/// Compute each distinct slot selected by a key together with the number of
/// hash functions that select it, allocating fresh result arrays.
fn unique_key_positions_fast(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : UInt64,
) -> CountingPositionSet {
  let capacity = if slot_count < hash_count.to_uint64() {
    slot_count.to_int()
  } else {
    hash_count
  }
  let positions = FixedArray::make(capacity, 0)
  let counts = FixedArray::make(capacity, 0)
  let length = unique_key_positions_into(
    h1, h2, hash_count, slot_count, positions, counts,
  )
  { positions, counts, length, }
}

///|
/// Compute the selected slots for `self`, reusing its probe workspace when one
/// is available.
fn CountingBloomFilter::positions_for(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> CountingPositionSet {
  if self.probe_positions.length() > 0 {
    let length = unique_key_positions_into(
      h1,
      h2,
      self.hash_count,
      self.slot_count.to_uint64(),
      self.probe_positions,
      self.probe_counts,
    )
    { positions: self.probe_positions, counts: self.probe_counts, length }
  } else {
    unique_key_positions_fast(
      h1, h2, self.hash_count, self.slot_count.to_uint64(),
    )
  }
}

///|
/// Compute each distinct slot selected by a key together with the number of
/// hash functions that select it.
///
/// Whitebox tests use the tuple view; the filter hot paths use
/// `unique_key_positions_fast` directly to avoid the per-probe tuple array.
#warnings("-unused_value")
fn unique_key_positions(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : UInt64,
) -> Array[(Int32, Int32)] {
  let set = unique_key_positions_fast(h1, h2, hash_count, slot_count)
  let unique : Array[(Int32, Int32)] = []
  for i = 0; i < set.length; i = i + 1 {
    unique.push((set.positions[i], set.counts[i]))
  }
  unique
}

///|
/// Raise every selected counter by the number of hash functions that select
/// it, capping at the largest multiple of that count that fits in 16 bits.
///
/// Capping below 65535 when a position repeats keeps the counter removable:
/// each removal subtracts exactly the same amount that each insertion added.
/// Every selected lane also advances by the same number of contributions, so
/// lanes with different repeat counts saturate together instead of stranding a
/// residue on the lanes that had more headroom.
fn CountingBloomFilter::raise_positions(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
  multiplicity : Int32,
) -> Unit {
  let positions = self.positions_for(h1, h2)
  self.raise_positions_at(positions, multiplicity)
}

///|
/// Record up to `multiplicity` complete contributions in every selected lane
/// independently.
///
/// Used when merging filters: a lane that is already saturated keeps its value,
/// which can still fund the shared removals, while the remaining lanes may have
/// room for the new occurrences. Capping every lane to the most saturated one
/// would leave a tracked multiplicity removable only in part.
fn CountingBloomFilter::raise_positions_independently_at(
  self : CountingBloomFilter,
  positions : CountingPositionSet,
  multiplicity : Int32,
) -> Unit {
  let wanted = multiplicity.to_uint64()
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let limit = counting_position_limit(occurrences)
    let value = self.counter_at(pos)
    if value < limit {
      let raised = value + wanted * occurrences
      self.set_counter(pos, if raised > limit { limit } else { raised })
    }
  }
}

///|
/// Add the occurrences of a key that a merge contributes to an existing slice.
fn CountingBloomFilter::raise_positions_for_merge(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
  multiplicity : Int32,
) -> Unit {
  let positions = self.positions_for(h1, h2)
  self.raise_positions_independently_at(positions, multiplicity)
}

///|
fn CountingBloomFilter::raise_positions_at(
  self : CountingBloomFilter,
  positions : CountingPositionSet,
  multiplicity : Int32,
) -> Unit {
  let wanted = multiplicity.to_uint64()
  if multiplicity > 1 {
    self.raise_positions_independently_at(positions, multiplicity)
    return
  }
  // A single insertion advances all counters of the key together. Saturation is
  // per position, so capping the lanes that still have room independently makes
  // one lane run out of recorded insertions before the others. The later
  // removals then stop early and leave positive residue on the remaining lanes
  // forever. Find how many complete contributions fit in every selected lane
  // and add the same number to all of them.
  let mut common = wanted
  let mut any_zero = false
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let limit = counting_position_limit(occurrences)
    let value = self.counter_at(pos)
    if value == 0UL {
      any_zero = true
    }
    let available = if value > limit {
      0UL
    } else {
      (limit - value) / occurrences
    }
    if available < common {
      common = available
    }
  }
  if common > 0UL {
    for i = 0; i < positions.length; i = i + 1 {
      let pos = positions.positions[i]
      let occurrences = positions.counts[i].to_uint64()
      let value = self.counter_at(pos)
      self.set_counter(pos, value + common * occurrences)
    }
    return
  }
  if !any_zero {
    return
  }
  // A zero lane means the key is not fully present yet. Add as many complete
  // contributions as the lane can hold, up to the requested multiplicity, so a
  // merge or conditional insertion cannot leave a tracked occurrence that no
  // later removal can drain. Lanes without room stay saturated.
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let limit = counting_position_limit(occurrences)
    let value = self.counter_at(pos)
    if value < limit {
      let raised = value + wanted * occurrences
      self.set_counter(pos, if raised > limit { limit } else { raised })
    }
  }
}

///|
fn CountingBloomFilter::increment_positions(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Unit {
  self.raise_positions(h1, h2, 1)
}

///|
/// Insert a key whose two hash values have already been computed.
fn CountingBloomFilter::insert_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("counting bloom filter insertion count overflow")
  }
  self.increment_positions(h1, h2)
  self.inserted += 1
}

///|
/// Insert `key` by incrementing every selected counter.
///
/// Counters at 65535 stay saturated. The insertion counter is incremented for
/// every call, including duplicate keys.
pub fn[K : Hash] CountingBloomFilter::insert(
  self : CountingBloomFilter,
  key : K,
) -> Unit {
  let (h1, h2) = key_hashes(key)
  self.insert_hashes(h1, h2)
}

///|
/// Insert a key with precomputed hashes when at least one counter is zero.
fn CountingBloomFilter::insert_if_absent_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  let positions = self.positions_for(h1, h2)
  for i = 0; i < positions.length; i = i + 1 {
    if self.counter_at(positions.positions[i]) == 0UL {
      guard self.inserted < 2147483647 else {
        abort("counting bloom filter insertion count overflow")
      }
      self.raise_positions_at(positions, 1)
      self.inserted += 1
      return true
    }
  }
  false
}

///|
/// Insert `key` only when at least one selected counter is zero.
///
/// Returns `true` when the key was inserted, or `false` when every selected
/// counter was positive and the key may already be present. False positives
/// can therefore suppress an insertion that would otherwise be harmless.
pub fn[K : Hash] CountingBloomFilter::insert_if_absent(
  self : CountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  self.insert_if_absent_hashes(h1, h2)
}

///|
/// Remove one insertion of `key` by decrementing every selected counter.
///
/// Returns `true` when all counters were positive and were decremented. A key
/// that was never inserted may still return `true` on a false positive and
/// remove another key's contribution; only remove keys known to be present.
pub fn[K : Hash] CountingBloomFilter::remove(
  self : CountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  self.remove_hashes(h1, h2)
}

///|
fn CountingBloomFilter::remove_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  let positions = self.positions_for(h1, h2)
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let required = if occurrences > 0xFFFFUL { 0xFFFFUL } else { occurrences }
    if self.counter_at(pos) < required {
      return false
    }
  }
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let value = self.counter_at(pos)
    let decrement = if value < occurrences { value } else { occurrences }
    self.set_counter(pos, value - decrement)
  }
  let needed = (self.counter_mass + self.hash_count.to_uint64() - 1UL) /
    self.hash_count.to_uint64()
  let mut next = if self.inserted > 0 { self.inserted - 1 } else { 0 }
  if needed > next.to_uint64() {
    next = needed.to_int()
  }
  self.inserted = next
  true
}

///|
/// Test a key whose two hash values have already been computed.
fn CountingBloomFilter::contains_hashes(
  self : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Bool {
  let slot_count = self.slot_count.to_uint64()
  let mut state = h1
  for i = 0; i < self.hash_count; i = i + 1 {
    if self.counter_at((state % slot_count).to_int()) == 0UL {
      return false
    }
    state = state + h2
  }
  true
}

///|
/// Test whether every counter selected by `key` is positive.
pub fn[K : Hash] CountingBloomFilter::contains(
  self : CountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  self.contains_hashes(h1, h2)
}

///|
/// Estimate how many insertions of `key` the filter currently represents.
///
/// The result is the smallest counter selected by `key`. It can exceed the
/// true multiplicity when other keys share those slots, and it is never lower
/// than the number of insertions unless a counter has saturated. A key that
/// hashes to a slot with a zero counter is reported as `0`.
pub fn[K : Hash] CountingBloomFilter::count_of(
  self : CountingBloomFilter,
  key : K,
) -> Int32 {
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  let mut state = h1
  let mut minimum = 65535UL
  for i = 0; i < self.hash_count; i = i + 1 {
    let value = self.counter_at((state % slot_count).to_int())
    if value == 0UL {
      return 0
    }
    if value < minimum {
      minimum = value
    }
    state = state + h2
  }
  minimum.to_int()
}

///|
/// Insert every key in `keys`. An empty view is a no-op.
pub fn[K : Hash] CountingBloomFilter::insert_all(
  self : CountingBloomFilter,
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
pub fn[K : Hash] CountingBloomFilter::insert_all_if_absent(
  self : CountingBloomFilter,
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
fn CountingBloomFilter::ensure_compatible(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Unit {
  guard self.slot_count == other.slot_count &&
    self.hash_count == other.hash_count else {
    abort("counting bloom filters must have the same slot and hash counts")
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
pub fn CountingBloomFilter::merge(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Unit {
  self.ensure_compatible(other)
  // An empty filter contributes no counters. Checking the counter mass as well
  // as the insertion count keeps the fast path safe even for a hand-built state
  // whose counters are positive but whose insertion count has already drained.
  if other.inserted == 0 && other.counter_mass == 0UL {
    return
  }
  // The receiver holds no counters, so lane-wise merging would only copy the
  // other filter while recomputing its mass. Copy the packed words and metadata
  // directly instead.
  if self.inserted == 0 && self.counter_mass == 0UL {
    for i = 0; i < self.counters.length(); i = i + 1 {
      self.counters[i] = other.counters[i]
    }
    self.counter_mass = other.counter_mass
    self.inserted = other.inserted
    return
  }
  guard self.inserted <= 2147483647 - other.inserted else {
    abort("counting bloom filter insertion count overflow")
  }
  let mut merged_mass = 0UL
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    if right == 0UL {
      merged_mass = merged_mass + counting_word_mass(left)
      continue
    }
    if left == 0UL {
      self.counters[i] = right
      merged_mass = merged_mass + counting_word_mass(right)
      continue
    }
    if left == right {
      merged_mass = merged_mass + counting_word_mass(left)
      continue
    }
    let merged = counting_lane_max(left, right)
    self.counters[i] = merged
    merged_mass = merged_mass + counting_word_mass(merged)
  }
  self.counter_mass = merged_mass
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
pub fn CountingBloomFilter::union(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> CountingBloomFilter {
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
pub fn CountingBloomFilter::intersection(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> CountingBloomFilter {
  self.ensure_compatible(other)
  // A filter with no insertions and no counter mass is truly empty, so the
  // intersection has no positive counters regardless of the other filter. Keep
  // the shared layout but skip the packed-counter scan.
  if (self.inserted == 0 && self.counter_mass == 0UL) ||
    (other.inserted == 0 && other.counter_mass == 0UL) {
    return CountingBloomFilter::with_size(self.slot_count, self.hash_count)
  }
  let result = CountingBloomFilter::with_size(self.slot_count, self.hash_count)
  let mut merged_mass = 0UL
  for i = 0; i < result.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    if left == 0UL || right == 0UL {
      continue
    }
    if left == right {
      result.counters[i] = left
      merged_mass = merged_mass + counting_word_mass(left)
      continue
    }
    let merged = counting_lane_min(left, right)
    result.counters[i] = merged
    merged_mass = merged_mass + counting_word_mass(merged)
  }
  result.counter_mass = merged_mass
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
pub fn CountingBloomFilter::is_subset_of(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  // The truly empty filter is a subset of every filter.
  if self.inserted == 0 && self.counter_mass == 0UL {
    return true
  }
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    if left == 0UL || left == right {
      continue
    }
    if counting_lane_min(left, right) != left {
      return false
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
pub fn CountingBloomFilter::is_disjoint_from(
  self : CountingBloomFilter,
  other : CountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  // An empty filter has no positive counter that could overlap.
  if (self.inserted == 0 && self.counter_mass == 0UL) ||
    (other.inserted == 0 && other.counter_mass == 0UL) {
    return true
  }
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = counting_nonzero_lanes(self.counters[i])
    let right = counting_nonzero_lanes(other.counters[i])
    if (left & right) != 0UL {
      return false
    }
  }
  true
}

///|
/// Test every key in `keys`, returning `false` at the first definite miss.
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
/// Test whether at least one key in `keys` may be present.
///
/// Returns `false` for an empty view.
pub fn[K : Hash] CountingBloomFilter::contains_any(
  self : CountingBloomFilter,
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
pub fn CountingBloomFilter::copy(
  self : CountingBloomFilter,
) -> CountingBloomFilter {
  {
    counters: self.counters.copy(),
    slot_count: self.slot_count,
    hash_count: self.hash_count,
    inserted: self.inserted,
    counter_mass: self.counter_mass,
    probe_positions: FixedArray::make(self.probe_positions.length(), 0),
    probe_counts: FixedArray::make(self.probe_counts.length(), 0),
  }
}

///|
/// Reset every counter and the insertion counter.
pub fn CountingBloomFilter::clear(self : CountingBloomFilter) -> Unit {
  for i = 0; i < self.counters.length(); i = i + 1 {
    self.counters[i] = 0UL
  }
  self.inserted = 0
  self.counter_mass = 0UL
}

///|
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn CountingBloomFilter::count(self : CountingBloomFilter) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion is currently outstanding.
pub fn CountingBloomFilter::is_empty(self : CountingBloomFilter) -> Bool {
  self.inserted == 0
}

///|
/// Number of addressable counters, always a multiple of 16.
pub fn CountingBloomFilter::slot_count(self : CountingBloomFilter) -> Int32 {
  self.slot_count
}

///|
/// Number of counters updated per operation.
pub fn CountingBloomFilter::hash_count(self : CountingBloomFilter) -> Int32 {
  self.hash_count
}

///|
/// Number of slots with a positive counter.
pub fn CountingBloomFilter::occupied_slot_count(
  self : CountingBloomFilter,
) -> Int32 {
  let mut total = 0
  for i = 0; i < self.counters.length(); i = i + 1 {
    total = total + counting_nonzero_lanes(self.counters[i]).popcnt()
  }
  total
}

///|
fn CountingBloomFilter::has_positive_counter(
  self : CountingBloomFilter,
) -> Bool {
  for i = 0; i < self.counters.length(); i = i + 1 {
    if counting_nonzero_lanes(self.counters[i]) != 0UL {
      return true
    }
  }
  false
}

///|
/// Fraction of slots with a positive counter, in `[0, 1]`.
pub fn CountingBloomFilter::fill_ratio(self : CountingBloomFilter) -> Double {
  self.occupied_slot_count().to_double() / self.slot_count.to_double()
}

///|
/// Estimate the number of distinct keys represented by the occupied slots.
///
/// Uses the same occupancy formula as `BloomFilter::estimated_item_count`, with
/// the slot count in place of the bit count.
pub fn CountingBloomFilter::estimated_item_count(
  self : CountingBloomFilter,
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
pub fn CountingBloomFilter::memory_bytes(self : CountingBloomFilter) -> Int64 {
  self.counters.length().to_int64() * 8L
}

///|
/// Estimated false-positive rate for the current insertion count.
///
/// Uses the same formula as `BloomFilter::false_positive_rate`, with the slot
/// count in place of the bit count.
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
