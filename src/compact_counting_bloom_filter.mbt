///|
/// A counting Bloom filter that packs each counter into a single nibble.
///
/// Counters are packed sixteen per `UInt64` as 4-bit values, so each slot costs
/// half a byte instead of the two bytes used by `CountingBloomFilter`. A counter
/// saturates at 15 instead of wrapping, which bounds how many insertions of the
/// same key the filter can represent but keeps the filter four times smaller.
/// Because a saturated counter is shared by every key that maps to it, removing
/// one key can drain another inserted key's contribution.
/// Removing a key that was never inserted can still corrupt the filter when it
/// produces a false positive, which is inherent to counting Bloom filters.
pub struct CompactCountingBloomFilter {
  priv counters : FixedArray[UInt64]
  priv slot_count : Int32
  priv hash_count : Int32
  priv mut inserted : Int32
  priv mut counter_mass : UInt64
  // Reusable probe buffers keep inserts and removals allocation-free. They are
  // left empty for layouts with an unusually wide hash count.
  priv probe_positions : FixedArray[Int32]
  priv probe_counts : FixedArray[Int32]
}

///|
const COMPACT_COUNTER_MAX : UInt64 = 0xFUL

///|
const COMPACT_SLOTS_PER_WORD : Int32 = 16

///|
/// Largest value a single packed counter can hold.
pub fn CompactCountingBloomFilter::counter_max() -> Int32 {
  COMPACT_COUNTER_MAX.to_int()
}

///|
/// Largest multiple of `occurrences` that fits in a 4-bit counter.
///
/// When one counter is selected several times by the same key, capping at a
/// multiple of that count keeps every removal able to subtract a full
/// contribution instead of leaving a residue below the required amount.
fn compact_position_limit(occurrences : UInt64) -> UInt64 {
  if occurrences > COMPACT_COUNTER_MAX {
    COMPACT_COUNTER_MAX
  } else {
    COMPACT_COUNTER_MAX - COMPACT_COUNTER_MAX % occurrences
  }
}

///|
/// Mark the high bit of every nibble whose counter is positive.
///
/// Adding the low three bits of each nibble to itself cannot carry into the
/// next nibble, so a bitwise AND of two masks identifies slots that are
/// positive in both filters.
fn compact_nonzero_lanes(word : UInt64) -> UInt64 {
  let low = word & 0x7777777777777777UL
  ((low + 0x7777777777777777UL) | (word & 0x8888888888888888UL)) &
  0x8888888888888888UL
}

///|
/// Sum the sixteen 4-bit counters packed into a word.
fn compact_word_mass(word : UInt64) -> UInt64 {
  let even = word & 0x0F0F0F0F0F0F0F0FUL
  let odd = (word >> 4) & 0x0F0F0F0F0F0F0F0FUL
  ((even * 0x0101010101010101UL) >> 56) + ((odd * 0x0101010101010101UL) >> 56)
}

///|
/// High bit of every 4-bit counter lane.
const COMPACT_LANE_SIGN : UInt64 = 0x8888888888888888UL

///|
/// Low three bits of every 4-bit counter lane.
const COMPACT_LANE_LOW : UInt64 = 0x7777777777777777UL

///|
/// Mark the high bit of every lane where `left` is at least `right`.
///
/// Forcing the high bit of `left` and clearing it in `right` keeps the
/// subtraction inside each lane, so a borrow never crosses lane boundaries. The
/// high bit of the difference is then set exactly for lanes whose low three
/// bits satisfy `left >= right`; lanes whose high bits differ are decided by
/// those high bits instead.
fn compact_lane_at_least(left : UInt64, right : UInt64) -> UInt64 {
  let different = (left ^ right) & COMPACT_LANE_SIGN
  let left_sign = left & COMPACT_LANE_SIGN
  let low_at_least = ((left | COMPACT_LANE_SIGN) - (right & COMPACT_LANE_LOW)) &
    COMPACT_LANE_SIGN
  (different & left_sign) | ((COMPACT_LANE_SIGN ^ different) & low_at_least)
}

///|
/// Take the larger of the two counters in every 4-bit lane.
fn compact_lane_max(left : UInt64, right : UInt64) -> UInt64 {
  let at_least = compact_lane_at_least(left, right)
  let lanes = (at_least >> 3) * 0xFUL
  right ^ ((left ^ right) & lanes)
}

///|
/// Take the smaller of the two counters in every 4-bit lane.
fn compact_lane_min(left : UInt64, right : UInt64) -> UInt64 {
  left ^ right ^ compact_lane_max(left, right)
}

///|
/// Compute the slot and hash counts that `CompactCountingBloomFilter::new`
/// would use.
///
/// Compact and regular counting filters share the same slot layout, so this
/// returns exactly the same pair as `CountingBloomFilter::optimal_size`. The
/// slot count is rounded up to a multiple of 16. Panics for the same invalid
/// arguments as `CompactCountingBloomFilter::new`.
pub fn CompactCountingBloomFilter::optimal_size(
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
/// Create a compact counting filter sized for `expected_items` and the target
/// `false_positive_rate`.
///
/// Panics if `expected_items` is not positive, the rate is not in `(0, 1)`, or
/// the requested filter would exceed the supported size.
pub fn CompactCountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> CompactCountingBloomFilter {
  let (slot_count, hash_count) = CompactCountingBloomFilter::optimal_size(
    expected_items, false_positive_rate,
  )
  CompactCountingBloomFilter::with_size(slot_count, hash_count)
}

///|
/// Create a compact counting filter with an explicit slot and hash count.
///
/// `slot_count` is rounded up to a multiple of 16 so counters pack evenly into
/// `UInt64` words.
pub fn CompactCountingBloomFilter::with_size(
  slot_count : Int32,
  hash_count : Int32,
) -> CompactCountingBloomFilter {
  guard slot_count > 0 && slot_count <= 1073741808 else {
    abort("slot_count must be positive and not too large")
  }
  guard hash_count > 0 else { abort("hash_count must be positive") }
  let rounded = (slot_count + 15) / 16 * 16
  let probe_length = counting_probe_length(hash_count, rounded)
  {
    counters: FixedArray::make(rounded / COMPACT_SLOTS_PER_WORD, 0UL),
    slot_count: rounded,
    hash_count,
    inserted: 0,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(probe_length, 0),
    probe_counts: FixedArray::make(probe_length, 0),
  }
}

///|
fn CompactCountingBloomFilter::counter_at(
  self : CompactCountingBloomFilter,
  position : Int32,
) -> UInt64 {
  let word = position / COMPACT_SLOTS_PER_WORD
  let shift = position % COMPACT_SLOTS_PER_WORD * 4
  (self.counters[word] >> shift) & COMPACT_COUNTER_MAX
}

///|
fn CompactCountingBloomFilter::set_counter(
  self : CompactCountingBloomFilter,
  position : Int32,
  value : UInt64,
) -> Unit {
  let word = position / COMPACT_SLOTS_PER_WORD
  let shift = position % COMPACT_SLOTS_PER_WORD * 4
  let value = if value > COMPACT_COUNTER_MAX {
    COMPACT_COUNTER_MAX
  } else {
    value
  }
  let old = (self.counters[word] >> shift) & COMPACT_COUNTER_MAX
  let cleared = self.counters[word] ^ (old << shift)
  self.counters[word] = cleared | (value << shift)
  self.counter_mass = self.counter_mass - old + value
}

///|
/// Compute the selected slots for `self`, reusing its probe workspace when one
/// is available.
fn CompactCountingBloomFilter::positions_for(
  self : CompactCountingBloomFilter,
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
/// Raise every selected counter by the number of hash functions that select
/// it, capping at the largest multiple of that count that fits in four bits.
///
/// Capping below 15 when a position repeats keeps the counter removable:
/// each removal subtracts exactly the same amount that each insertion added.
/// Every selected lane also advances by the same number of contributions, so
/// lanes with different repeat counts saturate together instead of stranding a
/// residue on the lanes that had more headroom.
fn CompactCountingBloomFilter::increment_positions(
  self : CompactCountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Unit {
  let positions = self.positions_for(h1, h2)
  self.increment_positions_at(positions)
}

///|
/// Apply a precomputed increment plan to every selected counter.
///
/// `common` is the number of complete contributions that fit in every selected
/// lane. When no such contribution fits but at least one lane is still zero,
/// the fallback advances each lane independently so a conditional insertion
/// cannot leave a false negative.
fn CompactCountingBloomFilter::apply_increment_positions_at(
  self : CompactCountingBloomFilter,
  positions : CountingPositionSet,
  common : UInt64,
  any_zero : Bool,
) -> Unit {
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
  // A zero lane means the key is not fully present yet. Add one complete
  // contribution where possible so a conditional insertion cannot leave a
  // false negative; lanes without room stay saturated.
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let limit = compact_position_limit(occurrences)
    let value = self.counter_at(pos)
    if value < limit {
      let raised = value + occurrences
      self.set_counter(pos, if raised > limit { limit } else { raised })
    }
  }
}

///|
fn CompactCountingBloomFilter::increment_positions_at(
  self : CompactCountingBloomFilter,
  positions : CountingPositionSet,
) -> Unit {
  // All counters of one key must advance together. Saturation is per position,
  // so capping the lanes that still have room independently makes one lane run
  // out of recorded insertions before the others. The later removals then stop
  // early and leave positive residue on the remaining lanes forever. Find how
  // many complete contributions fit in every selected lane and add the same
  // number to all of them.
  let mut common = 1UL
  let mut any_zero = false
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let limit = compact_position_limit(occurrences)
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
  self.apply_increment_positions_at(positions, common, any_zero)
}

///|
/// Insert one complete contribution if at least one selected counter is zero.
///
/// The zero check and the raise plan share one scan, so a conditional insertion
/// does not reread every selected nibble after deciding that it can proceed.
fn CompactCountingBloomFilter::insert_absent_at(
  self : CompactCountingBloomFilter,
  positions : CountingPositionSet,
) -> Bool {
  let mut common = 1UL
  let mut any_zero = false
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let limit = compact_position_limit(occurrences)
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
  if !any_zero {
    return false
  }
  guard self.inserted < 2147483647 else {
    abort("compact counting bloom filter insertion count overflow")
  }
  self.apply_increment_positions_at(positions, common, true)
  true
}

///|
/// Insert `key` by incrementing every selected counter.
///
/// Counters at 15 stay saturated. The insertion counter is incremented for
/// every call, including duplicate keys.
pub fn[K : Hash] CompactCountingBloomFilter::insert(
  self : CompactCountingBloomFilter,
  key : K,
) -> Unit {
  guard self.inserted < 2147483647 else {
    abort("compact counting bloom filter insertion count overflow")
  }
  let (h1, h2) = key_hashes(key)
  self.increment_positions(h1, h2)
  self.inserted += 1
}

///|
/// Insert `key` only when at least one selected counter is zero.
///
/// Returns `true` when the key was inserted, or `false` when every selected
/// counter was positive and the key may already be present. False positives can
/// therefore suppress an insertion that would otherwise be harmless.
pub fn[K : Hash] CompactCountingBloomFilter::insert_if_absent(
  self : CompactCountingBloomFilter,
  key : K,
) -> Bool {
  let (h1, h2) = key_hashes(key)
  // Every selected counter is already positive on a full filter, so the
  // conditional insertion is a false positive. Avoid enumerating a wide probe
  // sequence before reaching that conclusion.
  let slot_count = self.slot_count.to_uint64()
  let probes = counting_effective_probes(self.hash_count, h2, slot_count)
  if counting_should_check_full(probes, self.counters.length()) &&
    self.all_slots_positive() {
    return false
  }
  let positions = self.positions_for(h1, h2)
  if self.insert_absent_at(positions) {
    self.inserted += 1
    true
  } else {
    false
  }
}

///|
/// Remove one insertion of `key` by decrementing every selected counter.
///
/// Returns `true` when all counters were positive and were decremented. A key
/// that was never inserted may still return `true` on a false positive and
/// remove another key's contribution; only remove keys known to be present.
/// Saturated shared counters can also make a removal of an inserted key fail
/// after another key has drained the same positions.
pub fn[K : Hash] CompactCountingBloomFilter::remove(
  self : CompactCountingBloomFilter,
  key : K,
) -> Bool {
  // No counter is positive, so at least one required decrement must fail.
  if self.counter_mass == 0UL {
    return false
  }
  let (h1, h2) = key_hashes(key)
  let positions = self.positions_for(h1, h2)
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let required = if occurrences > COMPACT_COUNTER_MAX {
      COMPACT_COUNTER_MAX
    } else {
      occurrences
    }
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
/// Whether every addressable counter slot is positive.
///
/// A query cannot miss once every slot is positive: all of its probes land in
/// positive counters. Checking the packed mask words is much cheaper than
/// walking a very wide probe sequence on a non-power-of-two layout.
fn CompactCountingBloomFilter::all_slots_positive(
  self : CompactCountingBloomFilter,
) -> Bool {
  for i = 0; i < self.counters.length(); i = i + 1 {
    if compact_nonzero_lanes(self.counters[i]) != COMPACT_LANE_SIGN {
      return false
    }
  }
  true
}

///|
/// Test whether every counter selected by `key` is positive.
pub fn[K : Hash] CompactCountingBloomFilter::contains(
  self : CompactCountingBloomFilter,
  key : K,
) -> Bool {
  // No counter is positive, so no probe can succeed. This keeps a query on an
  // empty filter cheap even when a non-power-of-two slot count disables the
  // probe-cycle shortcut.
  if self.counter_mass == 0UL {
    return false
  }
  let (h1, h2) = key_hashes(key)
  let slot_count = self.slot_count.to_uint64()
  let probes = counting_effective_probes(self.hash_count, h2, slot_count)
  // A completely full filter reports every key present. Avoid walking a probe
  // sequence that is wider than the packed counter words just to rediscover
  // positive counters.
  if counting_should_check_full(probes, self.counters.length()) &&
    self.all_slots_positive() {
    return true
  }
  let mut state = h1
  for i = 0; i < probes; i = i + 1 {
    if self.counter_at((state % slot_count).to_int()) == 0UL {
      return false
    }
    state = state + h2
  }
  true
}

///|
/// Estimate how many insertions of `key` the filter currently represents.
///
/// The result is the smallest counter selected by `key`, normalized by the
/// number of times that slot is selected when the double-hash sequence repeats
/// a position, and capped at 15 because counters saturate. It can exceed the
/// true multiplicity when other keys share those slots, and it is never lower
/// than the number of insertions unless a counter has saturated. A key that
/// hashes to a zero counter is reported as `0`.
pub fn[K : Hash] CompactCountingBloomFilter::count_of(
  self : CompactCountingBloomFilter,
  key : K,
) -> Int32 {
  // An empty filter has no positive counter, so the minimum is zero without
  // probing a possibly very wide position sequence.
  if self.counter_mass == 0UL {
    return 0
  }
  let (h1, h2) = key_hashes(key)
  let positions = self.positions_for(h1, h2)
  let limit = CompactCountingBloomFilter::counter_max()
  let limit_u64 = limit.to_uint64()
  let mut minimum = limit
  let mut fallback = limit
  let mut have_estimate = false
  for i = 0; i < positions.length; i = i + 1 {
    let value = self.counter_at(positions.positions[i])
    if value == 0UL {
      return 0
    }
    // Repeated probes of one key add the same weighted contribution to a
    // slot on every insertion, so normalize by that count to report the
    // insertion multiplicity that remove also decrements.
    let raw = if value > limit_u64 { limit } else { value.to_int() }
    if raw < fallback {
      fallback = raw
    }
    let occurrences = positions.counts[i].to_uint64()
    // A slot selected more often than a nibble can hold saturates after the
    // first contribution, so it cannot reveal the multiplicity. Fall back to
    // the raw minimum when no selected slot can be normalized.
    if occurrences <= limit_u64 {
      let estimate_u64 = if value < occurrences {
        1UL
      } else {
        value / occurrences
      }
      let estimate = if estimate_u64 > limit_u64 {
        limit
      } else {
        estimate_u64.to_int()
      }
      if !have_estimate || estimate < minimum {
        minimum = estimate
        have_estimate = true
      }
    }
  }
  if have_estimate {
    minimum
  } else {
    fallback
  }
}

///|
/// Insert every key in `keys`. An empty view is a no-op.
pub fn[K : Hash] CompactCountingBloomFilter::insert_all(
  self : CompactCountingBloomFilter,
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
pub fn[K : Hash] CompactCountingBloomFilter::insert_all_if_absent(
  self : CompactCountingBloomFilter,
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
pub fn[K : Hash] CompactCountingBloomFilter::remove_all(
  self : CompactCountingBloomFilter,
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
fn CompactCountingBloomFilter::ensure_compatible(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Unit {
  guard self.slot_count == other.slot_count &&
    self.hash_count == other.hash_count else {
    abort(
      "compact counting bloom filters must have the same slot and hash counts",
    )
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
pub fn CompactCountingBloomFilter::merge(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Unit {
  self.ensure_compatible(other)
  // A source with no positive counter contributes no slot values, so only its
  // conservative insertion count changes the receiver. `counter_mass` is exact,
  // which avoids scanning every packed word for a count-only source.
  if other.counter_mass == 0UL {
    guard self.inserted <= 2147483647 - other.inserted else {
      abort("compact counting bloom filter insertion count overflow")
    }
    self.inserted += other.inserted
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
    abort("compact counting bloom filter insertion count overflow")
  }
  let mut merged_mass = 0UL
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    if right == 0UL {
      merged_mass = merged_mass + compact_word_mass(left)
      continue
    }
    if left == 0UL {
      self.counters[i] = right
      merged_mass = merged_mass + compact_word_mass(right)
      continue
    }
    if left == right {
      merged_mass = merged_mass + compact_word_mass(left)
      continue
    }
    let merged = compact_lane_max(left, right)
    self.counters[i] = merged
    merged_mass = merged_mass + compact_word_mass(merged)
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
pub fn CompactCountingBloomFilter::union(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
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
pub fn CompactCountingBloomFilter::intersection(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
  self.ensure_compatible(other)
  // A filter with no positive counter is truly empty, so the intersection has
  // no positive counters regardless of the other filter. Keep the shared layout
  // but skip the packed-counter scan. The insertion count stays the smaller of
  // the inputs, even when one input only carries a conservative count after
  // saturation drained its counters.
  if self.counter_mass == 0UL || other.counter_mass == 0UL {
    let result = CompactCountingBloomFilter::with_size(
      self.slot_count,
      self.hash_count,
    )
    result.inserted = self.inserted.min(other.inserted)
    return result
  }
  let result = CompactCountingBloomFilter::with_size(
    self.slot_count,
    self.hash_count,
  )
  let mut merged_mass = 0UL
  for i = 0; i < result.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    if left == 0UL || right == 0UL {
      continue
    }
    if left == right {
      result.counters[i] = left
      merged_mass = merged_mass + compact_word_mass(left)
      continue
    }
    let merged = compact_lane_min(left, right)
    result.counters[i] = merged
    merged_mass = merged_mass + compact_word_mass(merged)
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
pub fn CompactCountingBloomFilter::is_subset_of(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  // A filter with no positive counter is the empty set, regardless of its
  // conservative insertion count. Conversely, a non-empty filter cannot be a
  // subset of one whose counters are all zero. The exact counter mass answers
  // both cases without scanning the packed words.
  if self.counter_mass == 0UL {
    return true
  }
  if other.counter_mass == 0UL {
    return false
  }
  // Every counter in a subset is at most the corresponding counter in
  // `other`, so its exact total mass cannot exceed the other filter's mass.
  // This rejects most oversized operands without scanning the packed words.
  if self.counter_mass > other.counter_mass {
    return false
  }
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = self.counters[i]
    let right = other.counters[i]
    if left == 0UL || left == right {
      continue
    }
    if compact_lane_min(left, right) != left {
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
pub fn CompactCountingBloomFilter::is_disjoint_from(
  self : CompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Bool {
  self.ensure_compatible(other)
  // A filter with no positive counter cannot overlap anything.
  if self.counter_mass == 0UL || other.counter_mass == 0UL {
    return true
  }
  for i = 0; i < self.counters.length(); i = i + 1 {
    let left = compact_nonzero_lanes(self.counters[i])
    let right = compact_nonzero_lanes(other.counters[i])
    if (left & right) != 0UL {
      return false
    }
  }
  true
}

///|
/// Test every key in `keys`, returning `false` at the first definite miss.
pub fn[K : Hash] CompactCountingBloomFilter::contains_all(
  self : CompactCountingBloomFilter,
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
pub fn[K : Hash] CompactCountingBloomFilter::contains_any(
  self : CompactCountingBloomFilter,
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
pub fn CompactCountingBloomFilter::copy(
  self : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
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
pub fn CompactCountingBloomFilter::clear(
  self : CompactCountingBloomFilter,
) -> Unit {
  // The exact mass is zero only when every packed counter is already zero, so a
  // clear of an already empty filter can skip the backing-array scan.
  if self.counter_mass == 0UL {
    self.inserted = 0
    return
  }
  for i = 0; i < self.counters.length(); i = i + 1 {
    self.counters[i] = 0UL
  }
  self.inserted = 0
  self.counter_mass = 0UL
}

///|
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn CompactCountingBloomFilter::count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  self.inserted
}

///|
/// Whether no insertion is currently outstanding.
pub fn CompactCountingBloomFilter::is_empty(
  self : CompactCountingBloomFilter,
) -> Bool {
  self.inserted == 0
}

///|
/// Number of addressable counters, always a multiple of 16.
pub fn CompactCountingBloomFilter::slot_count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  self.slot_count
}

///|
/// Number of counters updated per operation.
pub fn CompactCountingBloomFilter::hash_count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  self.hash_count
}

///|
/// Number of slots with a positive counter.
pub fn CompactCountingBloomFilter::occupied_slot_count(
  self : CompactCountingBloomFilter,
) -> Int32 {
  if self.counter_mass == 0UL {
    return 0
  }
  let mut total = 0
  for i = 0; i < self.counters.length(); i = i + 1 {
    total = total + compact_nonzero_lanes(self.counters[i]).popcnt()
  }
  total
}

///|
/// Whether every counter slot is positive.
///
/// A full compact counting filter reports every key as present, although
/// removals can still free slots and insertions still advance counters and the
/// insertion count.
pub fn CompactCountingBloomFilter::is_full(
  self : CompactCountingBloomFilter,
) -> Bool {
  if self.counter_mass == 0UL {
    return false
  }
  self.all_slots_positive()
}

///|
/// Fraction of slots with a positive counter, in `[0, 1]`.
pub fn CompactCountingBloomFilter::fill_ratio(
  self : CompactCountingBloomFilter,
) -> Double {
  self.occupied_slot_count().to_double() / self.slot_count.to_double()
}

///|
/// Estimate the number of distinct keys represented by the occupied slots.
///
/// Uses the same occupancy formula as `BloomFilter::estimated_item_count`, with
/// the slot count in place of the bit count.
pub fn CompactCountingBloomFilter::estimated_item_count(
  self : CompactCountingBloomFilter,
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
///
/// This is four times smaller than an equivalent `CountingBloomFilter`, which
/// uses 16 bits per slot.
pub fn CompactCountingBloomFilter::memory_bytes(
  self : CompactCountingBloomFilter,
) -> Int64 {
  self.counters.length().to_int64() * 8L
}

///|
/// Estimated false-positive rate for the current insertion count.
///
/// Uses the same formula as `BloomFilter::false_positive_rate`, with the slot
/// count in place of the bit count.
pub fn CompactCountingBloomFilter::false_positive_rate(
  self : CompactCountingBloomFilter,
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
