///|
/// A thread-safe compact counting Bloom filter.
///
/// Every operation acquires the same mutex, so inserts, removals, queries, and
/// resets observe a consistent filter on native targets. On the JavaScript and
/// WebAssembly backends the mutex is a zero-cost no-op because those runtimes
/// execute a module on a single thread.
pub struct ConcurrentCompactCountingBloomFilter {
  priv state : @ref.Ref[CompactCountingBloomFilter]
  priv mutex : Mutex
}

///|
/// Largest value a single packed counter can hold.
pub fn ConcurrentCompactCountingBloomFilter::counter_max() -> Int32 {
  CompactCountingBloomFilter::counter_max()
}

///|
/// Create a thread-safe compact counting filter sized for `expected_items` and
/// the requested false-positive rate.
pub fn ConcurrentCompactCountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ConcurrentCompactCountingBloomFilter {
  {
    state: @ref.Ref(
      CompactCountingBloomFilter::new(expected_items, false_positive_rate),
    ),
    mutex: mutex_new(),
  }
}

///|
/// Create a thread-safe compact counting filter with an explicit slot and hash
/// count.
pub fn ConcurrentCompactCountingBloomFilter::with_size(
  slot_count : Int32,
  hash_count : Int32,
) -> ConcurrentCompactCountingBloomFilter {
  {
    state: @ref.Ref(
      CompactCountingBloomFilter::with_size(slot_count, hash_count),
    ),
    mutex: mutex_new(),
  }
}

///|
/// Compute the layout that `ConcurrentCompactCountingBloomFilter::new` would use
/// without allocating a backing array.
pub fn ConcurrentCompactCountingBloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  CompactCountingBloomFilter::optimal_size(expected_items, false_positive_rate)
}

///|
fn[R] ConcurrentCompactCountingBloomFilter::with_lock(
  self : ConcurrentCompactCountingBloomFilter,
  f : (CompactCountingBloomFilter) -> R,
) -> R {
  mutex_acquire(self.mutex)
  defer mutex_release(self.mutex)
  f(self.state.val)
}

///|
/// Insert a key. The operation is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::insert(
  self : ConcurrentCompactCountingBloomFilter,
  key : K,
) -> Unit {
  self.with_lock(filter => filter.insert(key))
}

///|
/// Insert a key only when it is definitely absent. The check and insertion are
/// atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::insert_if_absent(
  self : ConcurrentCompactCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert_if_absent(key))
}

///|
/// Remove one insertion of a key. The operation is atomic with respect to the
/// other methods.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::remove(
  self : ConcurrentCompactCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.remove(key))
}

///|
/// Estimate how many insertions of `key` the filter currently represents.
///
/// The lookup is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::count_of(
  self : ConcurrentCompactCountingBloomFilter,
  key : K,
) -> Int32 {
  self.with_lock(filter => filter.count_of(key))
}

///|
/// Test whether a key may be present.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::contains(
  self : ConcurrentCompactCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.contains(key))
}

///|
/// Insert every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::insert_all(
  self : ConcurrentCompactCountingBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  self.with_lock(filter => filter.insert_all(keys))
}

///|
/// Insert every key that is definitely absent while holding the lock once and
/// return how many were added.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::insert_all_if_absent(
  self : ConcurrentCompactCountingBloomFilter,
  keys : ArrayView[K],
) -> Int32 {
  self.with_lock(filter => filter.insert_all_if_absent(keys))
}

///|
/// Merge another filter into this one while holding the lock once.
///
/// The other filter must use the same slot and hash counts. Counters are
/// combined with the larger value and insertion counts are added.
pub fn ConcurrentCompactCountingBloomFilter::merge(
  self : ConcurrentCompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.merge(other))
}

///|
/// Build a compact counting filter containing every key present in either input
/// while holding the lock once.
///
/// The other filter must use the same slot and hash counts. The result is an
/// independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentCompactCountingBloomFilter::union(
  self : ConcurrentCompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
  self.with_lock(filter => filter.union(other))
}

///|
/// Build a compact counting filter containing only the keys reported present by
/// both inputs while holding the lock once.
///
/// The other filter must use the same slot and hash counts. The result is an
/// independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentCompactCountingBloomFilter::intersection(
  self : ConcurrentCompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
  self.with_lock(filter => filter.intersection(other))
}

///|
/// Whether every counter in the current filter is at most the corresponding
/// counter in `other`, while holding the lock once.
///
/// The other filter must use the same slot and hash counts.
pub fn ConcurrentCompactCountingBloomFilter::is_subset_of(
  self : ConcurrentCompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_subset_of(other))
}

///|
/// Whether the current filter and `other` are definitely disjoint, while
/// holding the lock once.
///
/// The other filter must use the same slot and hash counts.
pub fn ConcurrentCompactCountingBloomFilter::is_disjoint_from(
  self : ConcurrentCompactCountingBloomFilter,
  other : CompactCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_disjoint_from(other))
}

///|
/// Remove one insertion of every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::remove_all(
  self : ConcurrentCompactCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.remove_all(keys))
}

///|
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::contains_all(
  self : ConcurrentCompactCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
}

///|
/// Test whether at least one key in `keys` may be present while holding the
/// lock once.
pub fn[K : Hash] ConcurrentCompactCountingBloomFilter::contains_any(
  self : ConcurrentCompactCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_any(keys))
}

///|
/// Return an independent copy of the underlying filter.
///
/// This is equivalent to `snapshot()` and acquires the lock while copying.
pub fn ConcurrentCompactCountingBloomFilter::copy(
  self : ConcurrentCompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
  self.with_lock(filter => filter.copy())
}

///|
/// Return a consistent copy of the underlying filter.
///
/// The copy is independent, so it can be queried or modified without holding
/// the lock while other threads continue to update the concurrent filter.
pub fn ConcurrentCompactCountingBloomFilter::snapshot(
  self : ConcurrentCompactCountingBloomFilter,
) -> CompactCountingBloomFilter {
  self.copy()
}

///|
/// Remove all counters and reset the insertion count.
pub fn ConcurrentCompactCountingBloomFilter::clear(
  self : ConcurrentCompactCountingBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn ConcurrentCompactCountingBloomFilter::count(
  self : ConcurrentCompactCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether no insertion is currently outstanding.
pub fn ConcurrentCompactCountingBloomFilter::is_empty(
  self : ConcurrentCompactCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_empty())
}

///|
/// Number of addressable counters in the underlying filter.
pub fn ConcurrentCompactCountingBloomFilter::slot_count(
  self : ConcurrentCompactCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.slot_count())
}

///|
/// Number of counters updated per operation.
pub fn ConcurrentCompactCountingBloomFilter::hash_count(
  self : ConcurrentCompactCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.hash_count())
}

///|
/// Number of slots with a positive counter.
pub fn ConcurrentCompactCountingBloomFilter::occupied_slot_count(
  self : ConcurrentCompactCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.occupied_slot_count())
}

///|
/// Whether every counter slot is positive, while holding the lock once.
pub fn ConcurrentCompactCountingBloomFilter::is_full(
  self : ConcurrentCompactCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_full())
}

///|
/// Fraction of slots with a positive counter.
pub fn ConcurrentCompactCountingBloomFilter::fill_ratio(
  self : ConcurrentCompactCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.fill_ratio())
}

///|
/// Estimate the number of distinct keys represented by the occupied slots.
pub fn ConcurrentCompactCountingBloomFilter::estimated_item_count(
  self : ConcurrentCompactCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.estimated_item_count())
}

///|
/// Number of bytes occupied by the underlying packed counters.
pub fn ConcurrentCompactCountingBloomFilter::memory_bytes(
  self : ConcurrentCompactCountingBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}

///|
/// Estimated false-positive rate for the current insertion count.
pub fn ConcurrentCompactCountingBloomFilter::false_positive_rate(
  self : ConcurrentCompactCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}

///|
/// Encode the underlying filter as a portable byte sequence while holding the
/// lock.
pub fn ConcurrentCompactCountingBloomFilter::to_bytes(
  self : ConcurrentCompactCountingBloomFilter,
) -> Bytes {
  self.with_lock(filter => filter.to_bytes())
}

///|
/// Restore a thread-safe compact counting filter from data produced by
/// `to_bytes`.
///
/// Panics if the data is invalid, just like
/// `CompactCountingBloomFilter::from_bytes`.
pub fn ConcurrentCompactCountingBloomFilter::from_bytes(
  data : Bytes,
) -> ConcurrentCompactCountingBloomFilter {
  {
    state: @ref.Ref(CompactCountingBloomFilter::from_bytes(data)),
    mutex: mutex_new(),
  }
}
