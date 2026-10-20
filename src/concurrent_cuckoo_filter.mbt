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
  {
    state: @ref.Ref(CuckooFilter::new(expected_items)),
    mutex: mutex_new(),
  }
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
/// Remove all fingerprints and reset the insertion count.
pub fn ConcurrentCuckooFilter::clear(self : ConcurrentCuckooFilter) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of fingerprints currently stored.
pub fn ConcurrentCuckooFilter::count(
  self : ConcurrentCuckooFilter,
) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether the filter currently holds no fingerprints.
pub fn ConcurrentCuckooFilter::is_empty(
  self : ConcurrentCuckooFilter,
) -> Bool {
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
/// Fraction of slots currently holding a fingerprint.
pub fn ConcurrentCuckooFilter::load_factor(
  self : ConcurrentCuckooFilter,
) -> Double {
  self.with_lock(filter => filter.load_factor())
}

///|
/// Number of bytes occupied by the underlying fingerprint array.
pub fn ConcurrentCuckooFilter::memory_bytes(
  self : ConcurrentCuckooFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}
