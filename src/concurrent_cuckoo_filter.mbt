///|
/// A thread-safe cuckoo filter.
///
/// Every operation acquires the same mutex, so inserts, removals, queries, and
/// resets observe a consistent filter on native targets. On the JavaScript and
/// WebAssembly backends the mutex is a zero-cost no-op because those runtimes
/// execute a module on a single thread.
pub struct ConcurrentCuckooFilter {
  priv state : @ref.Ref[CuckooFilter]
  priv mutex : Mutex
}

///|
/// Create a thread-safe cuckoo filter sized to hold at least `expected_items`
/// entries.
pub fn ConcurrentCuckooFilter::new(
  expected_items : Int32,
) -> ConcurrentCuckooFilter {
  { state: @ref.Ref(CuckooFilter::new(expected_items)), mutex: mutex_new(), }
}

///|
/// Create a thread-safe cuckoo filter with an explicit bucket count and bucket
/// size.
pub fn ConcurrentCuckooFilter::with_size(
  bucket_count : Int32,
  bucket_size : Int32,
) -> ConcurrentCuckooFilter {
  {
    state: @ref.Ref(CuckooFilter::with_size(bucket_count, bucket_size)),
    mutex: mutex_new(),
  }
}

///|
fn[R] ConcurrentCuckooFilter::with_lock(
  self : ConcurrentCuckooFilter,
  f : (CuckooFilter) -> R,
) -> R {
  mutex_acquire(self.mutex)
  defer mutex_release(self.mutex)
  f(self.state.val)
}

///|
/// Insert a key, returning `false` if the filter is full. The operation is
/// atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCuckooFilter::insert(
  self : ConcurrentCuckooFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert(key))
}

///|
/// Insert a key only when its fingerprint is not already present. The check and
/// insertion are atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCuckooFilter::insert_if_absent(
  self : ConcurrentCuckooFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert_if_absent(key))
}

///|
/// Count the fingerprints matching a key in its candidate buckets. The lookup
/// is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentCuckooFilter::count_of(
  self : ConcurrentCuckooFilter,
  key : K,
) -> Int32 {
  self.with_lock(filter => filter.count_of(key))
}

///|
/// Remove one fingerprint matching a key. The operation is atomic with respect
/// to the other methods.
pub fn[K : Hash] ConcurrentCuckooFilter::remove(
  self : ConcurrentCuckooFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.remove(key))
}

///|
/// Test whether a key may be present.
pub fn[K : Hash] ConcurrentCuckooFilter::contains(
  self : ConcurrentCuckooFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.contains(key))
}

///|
/// Insert every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCuckooFilter::insert_all(
  self : ConcurrentCuckooFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.insert_all(keys))
}

///|
/// Insert every key whose fingerprint is not already present while holding the
/// lock once and return how many were added.
pub fn[K : Hash] ConcurrentCuckooFilter::insert_all_if_absent(
  self : ConcurrentCuckooFilter,
  keys : ArrayView[K],
) -> Int32 {
  self.with_lock(filter => filter.insert_all_if_absent(keys))
}

///|
/// Merge another filter into this one while holding the lock once.
///
/// Returns `false` and leaves the current state unchanged when the combined
/// fingerprints do not fit. The other filter must use the same layout.
pub fn ConcurrentCuckooFilter::merge(
  self : ConcurrentCuckooFilter,
  other : CuckooFilter,
) -> Bool {
  self.with_lock(filter => filter.merge(other))
}

///|
/// Build a filter containing every fingerprint of either input while holding
/// the lock once.
///
/// Returns `None` when the combined fingerprints do not fit. The other filter
/// must use the same bucket layout, and the concurrent receiver is left
/// unchanged.
pub fn ConcurrentCuckooFilter::union(
  self : ConcurrentCuckooFilter,
  other : CuckooFilter,
) -> CuckooFilter? {
  self.with_lock(filter => filter.union(other))
}

///|
/// Whether every fingerprint in the current filter is also present in `other`,
/// while holding the lock once.
///
/// The other filter must use the same bucket layout.
pub fn ConcurrentCuckooFilter::is_subset_of(
  self : ConcurrentCuckooFilter,
  other : CuckooFilter,
) -> Bool {
  self.with_lock(filter => filter.is_subset_of(other))
}

///|
/// Whether the current filter and `other` are definitely disjoint, while
/// holding the lock once.
///
/// The other filter must use the same bucket count and bucket size.
pub fn ConcurrentCuckooFilter::is_disjoint_from(
  self : ConcurrentCuckooFilter,
  other : CuckooFilter,
) -> Bool {
  self.with_lock(filter => filter.is_disjoint_from(other))
}

///|
/// Build a filter containing only the fingerprints present in both inputs while
/// holding the lock once.
///
/// The other filter must use the same bucket layout, and the concurrent
/// receiver is left unchanged. The result keeps the smaller per-bucket
/// multiplicity of every fingerprint.
pub fn ConcurrentCuckooFilter::intersection(
  self : ConcurrentCuckooFilter,
  other : CuckooFilter,
) -> CuckooFilter {
  self.with_lock(filter => filter.intersection(other))
}

///|
/// Remove one insertion of every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCuckooFilter::remove_all(
  self : ConcurrentCuckooFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.remove_all(keys))
}

///|
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentCuckooFilter::contains_all(
  self : ConcurrentCuckooFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
}

///|
/// Test whether at least one key in `keys` may be present while holding the
/// lock once.
pub fn[K : Hash] ConcurrentCuckooFilter::contains_any(
  self : ConcurrentCuckooFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_any(keys))
}

///|
/// Return a consistent copy of the underlying filter.
///
/// The copy is independent, so it can be queried or modified without holding
/// the lock while other threads continue to update the concurrent filter.
pub fn ConcurrentCuckooFilter::snapshot(
  self : ConcurrentCuckooFilter,
) -> CuckooFilter {
  self.with_lock(filter => filter.copy())
}

///|
/// Remove all fingerprints and reset the insertion count.
pub fn ConcurrentCuckooFilter::clear(self : ConcurrentCuckooFilter) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of fingerprints currently stored.
pub fn ConcurrentCuckooFilter::count(self : ConcurrentCuckooFilter) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether the filter currently holds no fingerprints.
pub fn ConcurrentCuckooFilter::is_empty(self : ConcurrentCuckooFilter) -> Bool {
  self.with_lock(filter => filter.is_empty())
}

///|
/// Number of buckets in the underlying filter.
pub fn ConcurrentCuckooFilter::bucket_count(
  self : ConcurrentCuckooFilter,
) -> Int32 {
  self.with_lock(filter => filter.bucket_count())
}

///|
/// Number of fingerprints each bucket can hold.
pub fn ConcurrentCuckooFilter::bucket_size(
  self : ConcurrentCuckooFilter,
) -> Int32 {
  self.with_lock(filter => filter.bucket_size())
}

///|
/// Total number of fingerprints the filter can hold.
pub fn ConcurrentCuckooFilter::capacity(self : ConcurrentCuckooFilter) -> Int32 {
  self.with_lock(filter => filter.capacity())
}

///|
/// Fraction of slots currently holding a fingerprint.
pub fn ConcurrentCuckooFilter::load_factor(
  self : ConcurrentCuckooFilter,
) -> Double {
  self.with_lock(filter => filter.load_factor())
}

///|
/// Estimate the false-positive rate from the average bucket occupancy.
pub fn ConcurrentCuckooFilter::false_positive_rate(
  self : ConcurrentCuckooFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}

///|
/// Number of bytes occupied by the underlying fingerprint array.
pub fn ConcurrentCuckooFilter::memory_bytes(
  self : ConcurrentCuckooFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}

///|
/// Encode the underlying filter as a portable byte sequence while holding the
/// lock.
pub fn ConcurrentCuckooFilter::to_bytes(self : ConcurrentCuckooFilter) -> Bytes {
  self.with_lock(filter => filter.to_bytes())
}

///|
/// Restore a thread-safe cuckoo filter from data produced by `to_bytes`.
///
/// Panics if the data is invalid, just like `CuckooFilter::from_bytes`.
pub fn ConcurrentCuckooFilter::from_bytes(
  data : Bytes,
) -> ConcurrentCuckooFilter {
  { state: @ref.Ref(CuckooFilter::from_bytes(data)), mutex: mutex_new(), }
}
