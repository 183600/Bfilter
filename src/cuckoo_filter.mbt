///|
/// A cuckoo filter with two candidate buckets per key and 8-bit fingerprints.
///
/// Each key is stored as a one-byte fingerprint derived from its hash, so the
/// filter uses roughly one byte per slot instead of the packed bits used by a
/// Bloom filter. Deletion is supported, and a failed insertion rolls back every
/// eviction so existing entries are preserved.
pub struct CuckooFilter {
  priv buckets : FixedArray[Byte]
  priv bucket_count : Int32
  priv bucket_size : Int32
  priv mut inserted : Int32
  priv mut random_state : UInt64
}

///|
const CUCKOO_BFS_BUCKET_LIMIT : Int32 = 65536

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
/// Create a filter sized to hold at least `expected_items` entries.
///
/// The bucket count is rounded up to a power of two, and four slots are used
/// per bucket. Panics if `expected_items` is not positive or too large.
pub fn CuckooFilter::new(expected_items : Int32) -> CuckooFilter {
  guard expected_items > 0 else { abort("expected_items must be positive") }
  guard expected_items <= 536870912 else {
    abort("expected_items is too large")
  }
  let bucket_size = 4
  let bucket_count = (expected_items * 2 - 1) / bucket_size + 1
  CuckooFilter::with_size(bucket_count, bucket_size)
}

///|
/// Create a filter with an explicit bucket count and bucket size.
///
/// `bucket_count` is rounded up to a power of two so alternate bucket indices
/// can be computed with masking. Panics for non-positive or oversized values.
pub fn CuckooFilter::with_size(
  bucket_count : Int32,
  bucket_size : Int32,
) -> CuckooFilter {
  guard bucket_count > 0 && bucket_count <= 1073741824 else {
    abort("bucket_count must be positive and not too large")
  }
  guard bucket_size > 0 else { abort("bucket_size must be positive") }
  let bucket_count = next_power_of_two(bucket_count)
  guard bucket_size <= 2147483627 / bucket_count else {
    abort("cuckoo filter size is too large")
  }
  let slot_count = bucket_count * bucket_size
  let seed = (bucket_count.to_uint64() << 32) | bucket_size.to_uint64() | 1UL
  {
    buckets: FixedArray::make(slot_count, b'\x00'),
    bucket_count,
    bucket_size,
    inserted: 0,
    random_state: mix64(seed),
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
  let (hash, _) = key_hashes(key)
  let mask = (self.bucket_count - 1).to_uint64()
  let index = (hash & mask).to_int()
  let fingerprint = ((hash >> 32) % 255UL + 1UL).to_byte()
  (index, fingerprint)
}

///|
/// Per-filter pseudo-random state used to pick eviction victims.
///
/// Cuckoo insertion walks a chain of alternate buckets; a deterministic victim
/// choice makes the chain revisit the same slots and fail well below capacity.
/// The state is seeded from the filter layout so behavior stays reproducible.
fn CuckooFilter::next_random(self : CuckooFilter) -> UInt64 {
  let mut state = self.random_state
  state = state ^ (state << 13)
  state = state ^ (state >> 7)
  state = state ^ (state << 17)
  self.random_state = state
  state
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
fn CuckooFilter::bucket_fingerprint_count(
  self : CuckooFilter,
  bucket : Int32,
  fingerprint : Byte,
) -> Int32 {
  let base = bucket * self.bucket_size
  let mut count = 0
  for slot = 0; slot < self.bucket_size; slot = slot + 1 {
    if self.buckets[base + slot] == fingerprint {
      count = count + 1
    }
  }
  count
}

///|
fn CuckooFilter::pair_fingerprint_count(
  self : CuckooFilter,
  bucket : Int32,
  fingerprint : Byte,
) -> Int32 {
  let alternate = self.alternate_index(bucket, fingerprint)
  let count = self.bucket_fingerprint_count(bucket, fingerprint)
  if alternate == bucket {
    count
  } else {
    count + self.bucket_fingerprint_count(alternate, fingerprint)
  }
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
/// Sparse variant of the augmenting-path search for filters whose dense
/// bookkeeping would be too large. The map stores the parent bucket and slot of
/// each visited bucket, and the search still stops after a bounded number of
/// buckets.
fn CuckooFilter::insert_fingerprint_bfs_sparse(
  self : CuckooFilter,
  start : Int32,
  fingerprint : Byte,
) -> Bool {
  let empty_start = self.find_empty(start)
  if empty_start >= 0 {
    self.buckets[start * self.bucket_size + empty_start] = fingerprint
    self.inserted += 1
    return true
  }
  let parent : @hashmap.HashMap[Int32, Int64] = @hashmap.HashMap([])
  let queue : Array[Int32] = [start]
  parent.set(start, -1L)
  let mut head = 0
  let mut explored = 1
  while head < queue.length() {
    let bucket = queue[head]
    head = head + 1
    let base = bucket * self.bucket_size
    for slot = 0; slot < self.bucket_size; slot = slot + 1 {
      let occupant = self.buckets[base + slot]
      let alternate = self.alternate_index(bucket, occupant)
      if alternate == bucket || parent.contains(alternate) {
        continue
      }
      let encoded = bucket.to_int64() * 4294967296L + slot.to_int64()
      let empty = self.find_empty(alternate)
      if empty >= 0 {
        parent.set(alternate, encoded)
        let mut child = alternate
        let mut empty_slot = empty
        while child != start {
          let previous = match parent.get(child) {
            Some(value) => value
            None => abort("missing cuckoo augmenting path parent")
          }
          let previous_bucket = (previous / 4294967296L).to_int()
          let previous_slot = (previous % 4294967296L).to_int()
          let moved = self.buckets[previous_bucket * self.bucket_size +
            previous_slot]
          self.buckets[child * self.bucket_size + empty_slot] = moved
          self.buckets[previous_bucket * self.bucket_size + previous_slot] = b'\x00'
          empty_slot = previous_slot
          child = previous_bucket
        }
        self.buckets[start * self.bucket_size + empty_slot] = fingerprint
        self.inserted += 1
        return true
      }
      parent.set(alternate, encoded)
      queue.push(alternate)
      explored = explored + 1
    }
    if explored > CUCKOO_BFS_BUCKET_LIMIT {
      return false
    }
  }
  false
}

///|
/// Try to make room for `fingerprint` by moving occupants along an augmenting
/// path from `start` to a bucket with an empty slot.
///
/// Each moved fingerprint stays inside its own candidate pair because it only
/// moves to the alternate bucket of its current bucket. A breadth-first search
/// finds such a path within a bounded number of buckets, which avoids reporting
/// the filter as full while a valid placement is still reachable. Small filters
/// use dense bookkeeping; larger filters use a sparse map so the search remains
/// bounded without allocating memory proportional to the whole filter.
fn CuckooFilter::insert_fingerprint_bfs(
  self : CuckooFilter,
  start : Int32,
  fingerprint : Byte,
) -> Bool {
  let empty_start = self.find_empty(start)
  if empty_start >= 0 {
    self.buckets[start * self.bucket_size + empty_start] = fingerprint
    self.inserted += 1
    return true
  }
  if self.bucket_count > CUCKOO_BFS_BUCKET_LIMIT {
    return self.insert_fingerprint_bfs_sparse(start, fingerprint)
  }
  let visited = FixedArray::make(self.bucket_count, false)
  let parent = FixedArray::make(self.bucket_count, -1)
  let parent_slot = FixedArray::make(self.bucket_count, -1)
  let queue : Array[Int32] = []
  queue.push(start)
  visited[start] = true
  let mut head = 0
  while head < queue.length() {
    let bucket = queue[head]
    head = head + 1
    let base = bucket * self.bucket_size
    for slot = 0; slot < self.bucket_size; slot = slot + 1 {
      let occupant = self.buckets[base + slot]
      let alternate = self.alternate_index(bucket, occupant)
      if alternate == bucket || visited[alternate] {
        continue
      }
      let empty = self.find_empty(alternate)
      if empty >= 0 {
        let mut child = alternate
        let mut empty_slot = empty
        parent[child] = bucket
        parent_slot[child] = slot
        while child != start {
          let previous = parent[child]
          let previous_slot = parent_slot[child]
          let moved = self.buckets[previous * self.bucket_size + previous_slot]
          self.buckets[child * self.bucket_size + empty_slot] = moved
          self.buckets[previous * self.bucket_size + previous_slot] = b'\x00'
          empty_slot = previous_slot
          child = previous
        }
        self.buckets[start * self.bucket_size + empty_slot] = fingerprint
        self.inserted += 1
        return true
      }
      visited[alternate] = true
      parent[alternate] = bucket
      parent_slot[alternate] = slot
      queue.push(alternate)
    }
  }
  false
}

///|
fn CuckooFilter::insert_fingerprint(
  self : CuckooFilter,
  index1 : Int32,
  fingerprint : Byte,
) -> Bool {
  if self.inserted >= self.capacity() {
    return false
  }
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
  for kick = 0; kick < 512; kick = kick + 1 {
    let empty = self.find_empty(index)
    if empty >= 0 {
      self.buckets[index * self.bucket_size + empty] = current
      self.inserted += 1
      return true
    }
    let slot = (self.next_random() % self.bucket_size.to_uint64()).to_int()
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
  if self.insert_fingerprint_bfs(index1, fingerprint) {
    true
  } else if index2 != index1 {
    self.insert_fingerprint_bfs(index2, fingerprint)
  } else {
    false
  }
}

///|
/// Insert `key`, returning `false` if the filter is full.
///
/// When both candidate buckets are full, the filter performs up to 512 random
/// evictions and then searches for an augmenting path to an empty slot. A
/// failed attempt restores all displaced fingerprints before returning, so a
/// failed insert never loses existing entries.
pub fn[K : Hash] CuckooFilter::insert(self : CuckooFilter, key : K) -> Bool {
  let (index1, fingerprint) = self.key_info(key)
  self.insert_fingerprint(index1, fingerprint)
}

///|
/// Insert `key` only when its fingerprint is not already present.
///
/// Returns `true` when the fingerprint was inserted. Returns `false` when the
/// key may already be present or when there was no room to insert it.
pub fn[K : Hash] CuckooFilter::insert_if_absent(
  self : CuckooFilter,
  key : K,
) -> Bool {
  let (index1, fingerprint) = self.key_info(key)
  let index2 = self.alternate_index(index1, fingerprint)
  if self.bucket_contains(index1, fingerprint) ||
    self.bucket_contains(index2, fingerprint) {
    false
  } else {
    self.insert_fingerprint(index1, fingerprint)
  }
}

///|
/// Test whether the fingerprint of `key` is present in either candidate
/// bucket. Results may contain false positives but never false negatives for
/// successfully inserted keys.
pub fn[K : Hash] CuckooFilter::contains(self : CuckooFilter, key : K) -> Bool {
  let (index1, fingerprint) = self.key_info(key)
  let index2 = self.alternate_index(index1, fingerprint)
  self.bucket_contains(index1, fingerprint) ||
  self.bucket_contains(index2, fingerprint)
}

///|
/// Count the fingerprints matching `key` in its two candidate buckets.
///
/// The result is the number of stored copies of the key's fingerprint. It can
/// be larger than the true multiplicity when another key with the same
/// fingerprint occupies a candidate bucket, but it is never lower than the
/// number of successful insertions.
pub fn[K : Hash] CuckooFilter::count_of(self : CuckooFilter, key : K) -> Int32 {
  let (index1, fingerprint) = self.key_info(key)
  self.pair_fingerprint_count(index1, fingerprint)
}

///|
/// Remove one fingerprint matching `key` from either candidate bucket.
///
/// Returns `false` when no matching fingerprint is present. Only remove keys
/// known to be inserted; removing a false positive can delete another key's
/// entry.
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
/// Insert every key in `keys`.
///
/// Continues after an insertion fails and returns `true` only when every key
/// was inserted. An empty view returns `true`.
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
/// Insert every key whose fingerprint is not already present and return how
/// many were added.
///
/// Keys that are already represented or that cannot fit are skipped. An empty
/// view returns `0`.
pub fn[K : Hash] CuckooFilter::insert_all_if_absent(
  self : CuckooFilter,
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
fn CuckooFilter::insert_fingerprints_from(
  self : CuckooFilter,
  other : CuckooFilter,
) -> Bool {
  for bucket = 0; bucket < other.bucket_count; bucket = bucket + 1 {
    let base = bucket * other.bucket_size
    for slot = 0; slot < other.bucket_size; slot = slot + 1 {
      let fingerprint = other.buckets[base + slot]
      if fingerprint != b'\x00' && !self.insert_fingerprint(bucket, fingerprint) {
        return false
      }
    }
  }
  true
}

///|
fn CuckooFilter::try_union_with(
  self : CuckooFilter,
  other : CuckooFilter,
) -> CuckooFilter? {
  let result = self.copy()
  if result.insert_fingerprints_from(other) {
    Some(result)
  } else {
    None
  }
}

///|
fn CuckooFilter::retry_union(
  first : CuckooFilter,
  second : CuckooFilter,
) -> CuckooFilter? {
  for attempt = 0; attempt < 16; attempt = attempt + 1 {
    let result = first.copy()
    result.random_state = mix64(
      result.random_state ^ ((attempt.to_uint64() + 1UL) * 0x2545F4914F6CDD1DUL),
    )
    if result.insert_fingerprints_from(second) {
      return Some(result)
    }
  }
  None
}

///|
/// Build a new filter that reports every key present in either input.
///
/// Both filters must use the same bucket count and bucket size. Fingerprints
/// are copied into their original buckets, which preserves each key's two
/// candidate buckets, and evictions keep that invariant. The combination is
/// retried with the inputs reversed and with fresh eviction randomness so a
/// result is not rejected merely because one input's existing placement blocks
/// the other. Returns `None` when the combined fingerprints do not fit in the
/// available slots; the inputs are left unchanged in that case.
pub fn CuckooFilter::union(
  self : CuckooFilter,
  other : CuckooFilter,
) -> CuckooFilter? {
  guard self.bucket_count == other.bucket_count &&
    self.bucket_size == other.bucket_size else {
    abort("cuckoo filters must have the same bucket count and size")
  }
  if self.inserted > self.capacity() - other.inserted {
    return None
  }
  if self.inserted == 0 {
    return Some(other.copy())
  }
  if other.inserted == 0 {
    return Some(self.copy())
  }
  match self.try_union_with(other) {
    Some(result) => Some(result)
    None =>
      match other.try_union_with(self) {
        Some(result) => Some(result)
        None =>
          match CuckooFilter::retry_union(self, other) {
            Some(result) => Some(result)
            None => CuckooFilter::retry_union(other, self)
          }
      }
  }
}

///|
/// Build the intersection of two filters with matching layouts.
///
/// A key's fingerprint may live in either of its two candidate buckets, and the
/// two inputs can store the same key in different buckets. Each unordered
/// candidate pair is processed once: if `self` holds the fingerprint in either
/// bucket and `other` holds it in either bucket, the pair contributes the
/// smaller of the two combined multiplicities. Surviving copies are placed in
/// the buckets where `self` stored them, so `contains` still finds a key that
/// both inputs report and the result can never drop a shared key. Every pair
/// contributes at most what either input held, so the result always fits and
/// its count never exceeds either input's count.
fn CuckooFilter::min_bucket_fingerprints(
  self : CuckooFilter,
  other : CuckooFilter,
) -> CuckooFilter {
  let result = CuckooFilter::with_size(self.bucket_count, self.bucket_size)
  if self.inserted == 0 || other.inserted == 0 {
    return result
  }
  let mut stored = 0
  let visited : @hashmap.HashMap[(Int32, Byte), Unit] = @hashmap.HashMap([])
  for bucket = 0; bucket < result.bucket_count; bucket = bucket + 1 {
    let base = bucket * result.bucket_size
    for slot = 0; slot < result.bucket_size; slot = slot + 1 {
      let fingerprint = self.buckets[base + slot]
      if fingerprint == b'\x00' ||
        self.bucket_fingerprint_count_prefix(bucket, slot, fingerprint) > 0 {
        continue
      }
      let alternate = self.alternate_index(bucket, fingerprint)
      let canonical = bucket.min(alternate)
      let pair = (canonical, fingerprint)
      if visited.contains(pair) {
        continue
      }
      visited.set(pair, ())
      let keep = self
        .pair_fingerprint_count(canonical, fingerprint)
        .min(other.pair_fingerprint_count(canonical, fingerprint))
      let mut remaining = keep
      let pair_bucket = self.alternate_index(canonical, fingerprint)
      let candidates : Array[Int32] = if pair_bucket == canonical {
        [canonical]
      } else {
        [canonical, pair_bucket]
      }
      for candidate in candidates {
        if remaining == 0 {
          break
        }
        let available = self.bucket_fingerprint_count(candidate, fingerprint)
        let placed = available.min(remaining)
        for i = 0; i < placed; i = i + 1 {
          let empty = result.find_empty(candidate)
          if empty < 0 {
            break
          }
          result.buckets[candidate * result.bucket_size + empty] = fingerprint
          stored = stored + 1
        }
        remaining = remaining - placed
      }
    }
  }
  result.inserted = stored
  result
}

///|
/// Count occurrences of `fingerprint` in `bucket` before `limit`.
///
/// Used to visit each distinct fingerprint in a bucket only once.
fn CuckooFilter::bucket_fingerprint_count_prefix(
  self : CuckooFilter,
  bucket : Int32,
  limit : Int32,
  fingerprint : Byte,
) -> Int32 {
  let base = bucket * self.bucket_size
  let mut count = 0
  for slot = 0; slot < limit; slot = slot + 1 {
    if self.buckets[base + slot] == fingerprint {
      count = count + 1
    }
  }
  count
}

///|
/// Build a new filter that reports every key present in both inputs.
///
/// Both filters must use the same bucket count and bucket size. For each bucket
/// the result keeps the smaller multiplicity of every fingerprint, so a key
/// stored in both filters survives while slots occupied by only one input are
/// dropped. The result always fits because neither bucket can hold more
/// fingerprints than either input did. The insertion count is the number of
/// surviving fingerprints.
pub fn CuckooFilter::intersection(
  self : CuckooFilter,
  other : CuckooFilter,
) -> CuckooFilter {
  guard self.bucket_count == other.bucket_count &&
    self.bucket_size == other.bucket_size else {
    abort("cuckoo filters must have the same bucket count and size")
  }
  self.min_bucket_fingerprints(other)
}

///|
/// Merge every fingerprint of `other` into `self` in place.
///
/// Both filters must use the same bucket count and bucket size. Returns `true`
/// when every fingerprint was added. If the combined fingerprints cannot fit,
/// returns `false` and leaves `self` unchanged.
pub fn CuckooFilter::merge(self : CuckooFilter, other : CuckooFilter) -> Bool {
  match self.union(other) {
    Some(result) => {
      for i = 0; i < self.buckets.length(); i = i + 1 {
        self.buckets[i] = result.buckets[i]
      }
      self.inserted = result.inserted
      self.random_state = result.random_state
      true
    }
    None => false
  }
}

///|
/// Whether every fingerprint in `self` is also present in `other`.
///
/// Both filters must use the same bucket count and bucket size. Fingerprints
/// are compared across each key's two candidate buckets and multiplicities are
/// preserved, so a `true` result means every key reported by `self` is also
/// reported by `other`. The check does not require the same physical slot.
pub fn CuckooFilter::is_subset_of(
  self : CuckooFilter,
  other : CuckooFilter,
) -> Bool {
  guard self.bucket_count == other.bucket_count &&
    self.bucket_size == other.bucket_size else {
    abort("cuckoo filters must have the same bucket count and size")
  }
  if self.inserted == 0 {
    return true
  }
  if self.inserted > other.inserted {
    return false
  }
  for bucket = 0; bucket < self.bucket_count; bucket = bucket + 1 {
    let base = bucket * self.bucket_size
    for slot = 0; slot < self.bucket_size; slot = slot + 1 {
      let fingerprint = self.buckets[base + slot]
      if fingerprint != b'\x00' &&
        self.bucket_fingerprint_count_prefix(bucket, slot, fingerprint) == 0 &&
        self.pair_fingerprint_count(bucket, fingerprint) >
        other.pair_fingerprint_count(bucket, fingerprint) {
        return false
      }
    }
  }
  true
}

///|
/// Whether `self` and `other` are definitely disjoint.
///
/// Both filters must use the same bucket count and bucket size. Returns `true`
/// only when no fingerprint stored in `self` also appears in the matching
/// candidate pair of `other`, which guarantees that no key can be reported
/// present by both. A `false` result is inconclusive because equal fingerprints
/// may come from different keys.
pub fn CuckooFilter::is_disjoint_from(
  self : CuckooFilter,
  other : CuckooFilter,
) -> Bool {
  guard self.bucket_count == other.bucket_count &&
    self.bucket_size == other.bucket_size else {
    abort("cuckoo filters must have the same bucket count and size")
  }
  if self.inserted == 0 || other.inserted == 0 {
    return true
  }
  for bucket = 0; bucket < self.bucket_count; bucket = bucket + 1 {
    let base = bucket * self.bucket_size
    for slot = 0; slot < self.bucket_size; slot = slot + 1 {
      let fingerprint = self.buckets[base + slot]
      if fingerprint != b'\x00' &&
        self.bucket_fingerprint_count_prefix(bucket, slot, fingerprint) == 0 &&
        other.pair_fingerprint_count(bucket, fingerprint) > 0 {
        return false
      }
    }
  }
  true
}

///|
/// Test every key in `keys`, returning `false` at the first definite miss.
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
/// Test whether at least one key in `keys` may be present.
///
/// Returns `false` for an empty view.
pub fn[K : Hash] CuckooFilter::contains_any(
  self : CuckooFilter,
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
/// Remove one insertion of every key in `keys`.
///
/// Continues after a removal fails and returns `true` only when all removals
/// succeeded. An empty view returns `true`.
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
/// Return an independent copy of the filter.
///
/// Later inserts or removals on either filter do not affect the other.
pub fn CuckooFilter::copy(self : CuckooFilter) -> CuckooFilter {
  {
    buckets: self.buckets.copy(),
    bucket_count: self.bucket_count,
    bucket_size: self.bucket_size,
    inserted: self.inserted,
    random_state: self.random_state,
  }
}

///|
/// Remove all fingerprints and reset the insertion counter.
pub fn CuckooFilter::clear(self : CuckooFilter) -> Unit {
  for i = 0; i < self.buckets.length(); i = i + 1 {
    self.buckets[i] = b'\x00'
  }
  self.inserted = 0
  let seed = (self.bucket_count.to_uint64() << 32) |
    self.bucket_size.to_uint64() |
    1UL
  self.random_state = mix64(seed)
}

///|
/// Number of successfully inserted fingerprints not yet removed.
pub fn CuckooFilter::count(self : CuckooFilter) -> Int32 {
  self.inserted
}

///|
/// Whether the filter currently holds no fingerprints.
pub fn CuckooFilter::is_empty(self : CuckooFilter) -> Bool {
  self.inserted == 0
}

///|
/// Number of buckets after rounding up to a power of two.
pub fn CuckooFilter::bucket_count(self : CuckooFilter) -> Int32 {
  self.bucket_count
}

///|
/// Number of fingerprints each bucket can hold.
pub fn CuckooFilter::bucket_size(self : CuckooFilter) -> Int32 {
  self.bucket_size
}

///|
/// Total number of fingerprints the filter can hold.
pub fn CuckooFilter::capacity(self : CuckooFilter) -> Int32 {
  self.bucket_count * self.bucket_size
}

///|
/// Fraction of slots currently holding a fingerprint, in `[0, 1]`.
pub fn CuckooFilter::load_factor(self : CuckooFilter) -> Double {
  self.inserted.to_double() / self.capacity().to_double()
}

///|
/// Estimate the false-positive rate from the average bucket occupancy.
///
/// A query checks two buckets and compares eight-bit fingerprints, so the
/// estimate is `1 - (1 - 1/256)^(2 * load)`, where `load` is the average number
/// of fingerprints per bucket. An empty filter returns `0`.
pub fn CuckooFilter::false_positive_rate(self : CuckooFilter) -> Double {
  if self.inserted == 0 {
    0.0
  } else {
    let average_load = self.inserted.to_double() / self.bucket_count.to_double()
    1.0 - @math.pow(1.0 - 1.0 / 256.0, 2.0 * average_load)
  }
}

///|
/// Number of bytes occupied by the fingerprint array.
pub fn CuckooFilter::memory_bytes(self : CuckooFilter) -> Int64 {
  self.buckets.length().to_int64()
}
