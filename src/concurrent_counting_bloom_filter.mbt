///|
/// A thread-safe counting Bloom filter.
///
/// Every operation acquires the same mutex, so inserts, removals, queries, and
/// resets observe a consistent filter on native targets. On the JavaScript and
/// WebAssembly backends the mutex is a zero-cost no-op because those runtimes
/// execute a module on a single thread.
pub struct ConcurrentCountingBloomFilter {
  priv state : @ref.Ref[CountingBloomFilter]
  priv mutex : Mutex
}

///|
/// Create a thread-safe counting Bloom filter sized for `expected_items` and
/// the requested false-positive rate.
pub fn ConcurrentCountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ConcurrentCountingBloomFilter {
  {
    state: @ref.Ref(
      CountingBloomFilter::new(expected_items, false_positive_rate),
    ),
    mutex: mutex_new(),
  }
}

///|
/// Create a thread-safe counting Bloom filter with an explicit slot and hash
/// count.
pub fn ConcurrentCountingBloomFilter::with_size(
  slot_count : Int32,
  hash_count : Int32,
) -> ConcurrentCountingBloomFilter {
  {
    state: @ref.Ref(CountingBloomFilter::with_size(slot_count, hash_count)),
    mutex: mutex_new(),
  }
}

///|
fn[R] ConcurrentCountingBloomFilter::with_lock(
  self : ConcurrentCountingBloomFilter,
  f : (CountingBloomFilter) -> R,
) -> R {
  mutex_acquire(self.mutex)
  defer mutex_release(self.mutex)
  f(self.state.val)
}

///|
/// Insert a key. The operation is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCountingBloomFilter::insert(
  self : ConcurrentCountingBloomFilter,
  key : K,
) -> Unit {
  self.with_lock(filter => filter.insert(key))
}

///|
/// Insert a key only when it is definitely absent. The check and insertion are
/// atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCountingBloomFilter::insert_if_absent(
  self : ConcurrentCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert_if_absent(key))
}

///|
/// Remove one insertion of a key. The operation is atomic with respect to the
/// other methods.
pub fn[K : Hash] ConcurrentCountingBloomFilter::remove(
  self : ConcurrentCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.remove(key))
}

///|
/// Estimate how many insertions of `key` the filter currently represents.
///
/// The lookup is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCountingBloomFilter::count_of(
  self : ConcurrentCountingBloomFilter,
  key : K,
) -> Int32 {
  self.with_lock(filter => filter.count_of(key))
}

///|
/// Test whether a key may be present.
pub fn[K : Hash] ConcurrentCountingBloomFilter::contains(
  self : ConcurrentCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.contains(key))
}

///|
/// Insert every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCountingBloomFilter::insert_all(
  self : ConcurrentCountingBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  self.with_lock(filter => filter.insert_all(keys))
}

///|
/// Insert every key that is definitely absent while holding the lock once and
/// return how many were added.
pub fn[K : Hash] ConcurrentCountingBloomFilter::insert_all_if_absent(
  self : ConcurrentCountingBloomFilter,
  keys : ArrayView[K],
) -> Int32 {
  self.with_lock(filter => filter.insert_all_if_absent(keys))
}

///|
/// Merge another filter into this one while holding the lock once.
///
/// The other filter must use the same slot and hash counts. Counters are
/// combined with the larger value and insertion counts are added.
pub fn ConcurrentCountingBloomFilter::merge(
  self : ConcurrentCountingBloomFilter,
  other : CountingBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.merge(other))
}

///|
/// Build a counting filter containing every key present in either input while
/// holding the lock once.
///
/// The other filter must use the same slot and hash counts. The result is an
/// independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentCountingBloomFilter::union(
  self : ConcurrentCountingBloomFilter,
  other : CountingBloomFilter,
) -> CountingBloomFilter {
  self.with_lock(filter => filter.union(other))
}

///|
/// Build a counting filter containing only the keys reported present by both
/// inputs while holding the lock once.
///
/// The other filter must use the same slot and hash counts. The result is an
/// independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentCountingBloomFilter::intersection(
  self : ConcurrentCountingBloomFilter,
  other : CountingBloomFilter,
) -> CountingBloomFilter {
  self.with_lock(filter => filter.intersection(other))
}

///|
/// Whether every counter in the current filter is at most the corresponding
/// counter in `other`, while holding the lock once.
///
/// The other filter must use the same slot and hash counts.
pub fn ConcurrentCountingBloomFilter::is_subset_of(
  self : ConcurrentCountingBloomFilter,
  other : CountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_subset_of(other))
}

///|
/// Whether the current filter and `other` are definitely disjoint, while
/// holding the lock once.
///
/// The other filter must use the same slot and hash counts.
pub fn ConcurrentCountingBloomFilter::is_disjoint_from(
  self : ConcurrentCountingBloomFilter,
  other : CountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_disjoint_from(other))
}

///|
/// Remove one insertion of every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCountingBloomFilter::remove_all(
  self : ConcurrentCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.remove_all(keys))
}

///|
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCountingBloomFilter::contains_all(
  self : ConcurrentCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
}

///|
/// Test whether at least one key in `keys` may be present while holding the
/// lock once.
pub fn[K : Hash] ConcurrentCountingBloomFilter::contains_any(
  self : ConcurrentCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_any(keys))
}

///|
/// Return a consistent copy of the underlying filter.
///
/// The copy is independent, so it can be queried or modified without holding
/// the lock while other threads continue to update the concurrent filter.
pub fn ConcurrentCountingBloomFilter::snapshot(
  self : ConcurrentCountingBloomFilter,
) -> CountingBloomFilter {
  self.with_lock(filter => filter.copy())
}

///|
/// Remove all counters and reset the insertion count.
pub fn ConcurrentCountingBloomFilter::clear(
  self : ConcurrentCountingBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn ConcurrentCountingBloomFilter::count(
  self : ConcurrentCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether no insertion is currently outstanding.
pub fn ConcurrentCountingBloomFilter::is_empty(
  self : ConcurrentCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_empty())
}

///|
/// Number of addressable counters in the underlying filter.
pub fn ConcurrentCountingBloomFilter::slot_count(
  self : ConcurrentCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.slot_count())
}

///|
/// Largest value a single underlying 16-bit counter can hold.
pub fn ConcurrentCountingBloomFilter::counter_max() -> Int32 {
  CountingBloomFilter::counter_max()
}

///|
/// Number of counters updated per operation.
pub fn ConcurrentCountingBloomFilter::hash_count(
  self : ConcurrentCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.hash_count())
}

///|
/// Number of slots with a positive counter.
pub fn ConcurrentCountingBloomFilter::occupied_slot_count(
  self : ConcurrentCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.occupied_slot_count())
}

///|
/// Fraction of slots with a positive counter.
pub fn ConcurrentCountingBloomFilter::fill_ratio(
  self : ConcurrentCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.fill_ratio())
}

///|
/// Estimate the number of distinct keys represented by the occupied slots.
pub fn ConcurrentCountingBloomFilter::estimated_item_count(
  self : ConcurrentCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.estimated_item_count())
}

///|
/// Number of bytes occupied by the underlying packed counters.
pub fn ConcurrentCountingBloomFilter::memory_bytes(
  self : ConcurrentCountingBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}

///|
/// Estimated false-positive rate for the current insertion count.
pub fn ConcurrentCountingBloomFilter::false_positive_rate(
  self : ConcurrentCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}

///|
/// Encode the underlying filter as a portable byte sequence while holding the
/// lock.
pub fn ConcurrentCountingBloomFilter::to_bytes(
  self : ConcurrentCountingBloomFilter,
) -> Bytes {
  self.with_lock(filter => filter.to_bytes())
}

///|
/// Restore a thread-safe counting filter from data produced by `to_bytes`.
///
/// Panics if the data is invalid, just like `CountingBloomFilter::from_bytes`.
pub fn ConcurrentCountingBloomFilter::from_bytes(
  data : Bytes,
) -> ConcurrentCountingBloomFilter {
  {
    state: @ref.Ref(CountingBloomFilter::from_bytes(data)),
    mutex: mutex_new(),
  }
}
