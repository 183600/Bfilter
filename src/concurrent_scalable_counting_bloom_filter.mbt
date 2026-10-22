///|
/// A thread-safe scalable counting Bloom filter.
///
/// Every operation acquires the same mutex, so slice growth, removals, and
/// queries observe a consistent filter on native targets. On the JavaScript and
/// WebAssembly backends the mutex is a zero-cost no-op because those runtimes
/// execute a module on a single thread.
pub struct ConcurrentScalableCountingBloomFilter {
  priv state : @ref.Ref[ScalableCountingBloomFilter]
  priv mutex : Mutex
}

///|
/// Create a thread-safe growing counting filter sized for an initial
/// `expected_items` keys and the target `false_positive_rate`.
pub fn ConcurrentScalableCountingBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ConcurrentScalableCountingBloomFilter {
  {
    state: @ref.Ref(
      ScalableCountingBloomFilter::new(expected_items, false_positive_rate),
    ),
    mutex: mutex_new(),
  }
}

///|
fn[R] ConcurrentScalableCountingBloomFilter::with_lock(
  self : ConcurrentScalableCountingBloomFilter,
  f : (ScalableCountingBloomFilter) -> R,
) -> R {
  mutex_acquire(self.mutex)
  defer mutex_release(self.mutex)
  f(self.state.val)
}

///|
/// Insert a key. The operation is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::insert(
  self : ConcurrentScalableCountingBloomFilter,
  key : K,
) -> Unit {
  self.with_lock(filter => filter.insert(key))
}

///|
/// Insert a key only when it is definitely absent. The check across slices and
/// the insertion are atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::insert_if_absent(
  self : ConcurrentScalableCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert_if_absent(key))
}

///|
/// Remove one tracked insertion of a key.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::remove(
  self : ConcurrentScalableCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.remove(key))
}

///|
/// Return the exact tracked multiplicity of a key.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::count_of(
  self : ConcurrentScalableCountingBloomFilter,
  key : K,
) -> Int32 {
  self.with_lock(filter => filter.count_of(key))
}

///|
/// Test whether any slice may contain a key.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::contains(
  self : ConcurrentScalableCountingBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.contains(key))
}

///|
/// Insert every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::insert_all(
  self : ConcurrentScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  self.with_lock(filter => filter.insert_all(keys))
}

///|
/// Insert every key that is definitely absent while holding the lock once and
/// return how many were added.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::insert_all_if_absent(
  self : ConcurrentScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Int32 {
  self.with_lock(filter => filter.insert_all_if_absent(keys))
}

///|
/// Remove one tracked insertion of every key in `keys` while holding the lock
/// once.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::remove_all(
  self : ConcurrentScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.remove_all(keys))
}

///|
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::contains_all(
  self : ConcurrentScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
}

///|
/// Test whether at least one key in `keys` may be present while holding the
/// lock once.
pub fn[K : Hash] ConcurrentScalableCountingBloomFilter::contains_any(
  self : ConcurrentScalableCountingBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_any(keys))
}

///|
/// Merge another filter into this one while holding the lock once.
///
/// The other filter must share the initial capacity and target rate. Its slices
/// and tracked keys are combined with the current state and its insertion count
/// is added.
pub fn ConcurrentScalableCountingBloomFilter::merge(
  self : ConcurrentScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.merge(other))
}

///|
/// Build a scalable counting filter containing every key present in either
/// input while holding the lock once.
///
/// The other filter must share the initial capacity and target rate. The result
/// is an independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentScalableCountingBloomFilter::union(
  self : ConcurrentScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> ScalableCountingBloomFilter {
  self.with_lock(filter => filter.union(other))
}

///|
/// Build a scalable counting filter containing keys tracked by both inputs
/// while holding the lock once.
///
/// The other filter must share the initial capacity and target rate. The result
/// is an independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentScalableCountingBloomFilter::intersection(
  self : ConcurrentScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> ScalableCountingBloomFilter {
  self.with_lock(filter => filter.intersection(other))
}

///|
/// Whether every key reported present by the current filter is also reported
/// present by `other`, while holding the lock once.
///
/// The other filter must share the initial capacity and target rate.
pub fn ConcurrentScalableCountingBloomFilter::is_subset_of(
  self : ConcurrentScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_subset_of(other))
}

///|
/// Whether the current filter and `other` are definitely disjoint, while
/// holding the lock once.
///
/// The other filter must share the initial capacity and target rate.
pub fn ConcurrentScalableCountingBloomFilter::is_disjoint_from(
  self : ConcurrentScalableCountingBloomFilter,
  other : ScalableCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_disjoint_from(other))
}

///|
/// Return a consistent copy of the underlying filter, including slices and
/// location metadata.
pub fn ConcurrentScalableCountingBloomFilter::snapshot(
  self : ConcurrentScalableCountingBloomFilter,
) -> ScalableCountingBloomFilter {
  self.with_lock(filter => filter.copy())
}

///|
/// Reset the filter to a single empty slice.
pub fn ConcurrentScalableCountingBloomFilter::clear(
  self : ConcurrentScalableCountingBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of insertions not yet removed since creation or the last `clear`.
pub fn ConcurrentScalableCountingBloomFilter::count(
  self : ConcurrentScalableCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether no insertion is currently outstanding.
pub fn ConcurrentScalableCountingBloomFilter::is_empty(
  self : ConcurrentScalableCountingBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_empty())
}

///|
/// Number of distinct keys currently tracked for deletion.
pub fn ConcurrentScalableCountingBloomFilter::tracked_key_count(
  self : ConcurrentScalableCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.tracked_key_count())
}

///|
/// Number of slices currently backing the filter.
pub fn ConcurrentScalableCountingBloomFilter::slice_count(
  self : ConcurrentScalableCountingBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.slice_count())
}

///|
/// Sum of the planned capacities of the current slices.
pub fn ConcurrentScalableCountingBloomFilter::capacity(
  self : ConcurrentScalableCountingBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.capacity())
}

///|
/// Number of counter slots across all slices.
pub fn ConcurrentScalableCountingBloomFilter::slot_count(
  self : ConcurrentScalableCountingBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.slot_count())
}

///|
/// Number of non-zero counter slots across all slices.
pub fn ConcurrentScalableCountingBloomFilter::occupied_slot_count(
  self : ConcurrentScalableCountingBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.occupied_slot_count())
}

///|
/// Fraction of counter slots currently non-zero.
pub fn ConcurrentScalableCountingBloomFilter::fill_ratio(
  self : ConcurrentScalableCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.fill_ratio())
}

///|
/// Estimate the number of distinct keys represented by the current counters.
pub fn ConcurrentScalableCountingBloomFilter::estimated_item_count(
  self : ConcurrentScalableCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.estimated_item_count())
}

///|
/// Target false-positive rate requested at construction time.
pub fn ConcurrentScalableCountingBloomFilter::target_false_positive_rate(
  self : ConcurrentScalableCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.target_false_positive_rate())
}

///|
/// Estimated current false-positive rate across all slices.
pub fn ConcurrentScalableCountingBloomFilter::false_positive_rate(
  self : ConcurrentScalableCountingBloomFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}

///|
/// Number of bytes occupied by the counter arrays of all slices.
pub fn ConcurrentScalableCountingBloomFilter::memory_bytes(
  self : ConcurrentScalableCountingBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}

///|
/// Encode the underlying filter as a portable byte sequence while holding the
/// lock.
pub fn ConcurrentScalableCountingBloomFilter::to_bytes(
  self : ConcurrentScalableCountingBloomFilter,
) -> Bytes {
  self.with_lock(filter => filter.to_bytes())
}

///|
/// Restore a thread-safe scalable counting filter from data produced by
/// `to_bytes`.
///
/// Panics if the data is invalid, just like
/// `ScalableCountingBloomFilter::from_bytes`.
pub fn ConcurrentScalableCountingBloomFilter::from_bytes(
  data : Bytes,
) -> ConcurrentScalableCountingBloomFilter {
  {
    state: @ref.Ref(ScalableCountingBloomFilter::from_bytes(data)),
    mutex: mutex_new(),
  }
}
