///|
/// A thread-safe scalable Bloom filter.
///
/// Every operation acquires the same mutex, so slice growth and queries observe
/// a consistent filter on native targets. On the JavaScript and WebAssembly
/// backends the mutex is a zero-cost no-op because those runtimes execute a
/// module on a single thread.
pub struct ConcurrentScalableBloomFilter {
  priv state : @ref.Ref[ScalableBloomFilter]
  priv mutex : Mutex
}

///|
/// Create a thread-safe growing Bloom filter sized for an initial
/// `expected_items` keys and the target `false_positive_rate`.
pub fn ConcurrentScalableBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ConcurrentScalableBloomFilter {
  {
    state: @ref.Ref(
      ScalableBloomFilter::new(expected_items, false_positive_rate),
    ),
    mutex: mutex_new(),
  }
}

///|
fn[R] ConcurrentScalableBloomFilter::with_lock(
  self : ConcurrentScalableBloomFilter,
  f : (ScalableBloomFilter) -> R,
) -> R {
  mutex_acquire(self.mutex)
  defer mutex_release(self.mutex)
  f(self.state.val)
}

///|
/// Insert a key. The operation is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentScalableBloomFilter::insert(
  self : ConcurrentScalableBloomFilter,
  key : K,
) -> Unit {
  self.with_lock(filter => filter.insert(key))
}

///|
/// Insert a key only when it is definitely absent. The check across slices and
/// the insertion are atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentScalableBloomFilter::insert_if_absent(
  self : ConcurrentScalableBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert_if_absent(key))
}

///|
/// Test whether any slice may contain a key.
pub fn[K : Hash] ConcurrentScalableBloomFilter::contains(
  self : ConcurrentScalableBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.contains(key))
}

///|
/// Insert every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentScalableBloomFilter::insert_all(
  self : ConcurrentScalableBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  self.with_lock(filter => filter.insert_all(keys))
}

///|
/// Insert every key that is definitely absent while holding the lock once and
/// return how many were added.
pub fn[K : Hash] ConcurrentScalableBloomFilter::insert_all_if_absent(
  self : ConcurrentScalableBloomFilter,
  keys : ArrayView[K],
) -> Int32 {
  self.with_lock(filter => filter.insert_all_if_absent(keys))
}

///|
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentScalableBloomFilter::contains_all(
  self : ConcurrentScalableBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
}

///|
/// Test whether at least one key in `keys` may be present while holding the
/// lock once.
pub fn[K : Hash] ConcurrentScalableBloomFilter::contains_any(
  self : ConcurrentScalableBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_any(keys))
}

///|
/// Merge another filter into this one while holding the lock once.
///
/// The other filter must share the initial capacity and target rate. Its
/// slices are combined with the current state and its insertion count is
/// added.
pub fn ConcurrentScalableBloomFilter::merge(
  self : ConcurrentScalableBloomFilter,
  other : ScalableBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.merge(other))
}

///|
/// Build a scalable filter containing every key present in either input while
/// holding the lock once.
///
/// The other filter must share the initial capacity and target rate. The
/// result is an independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentScalableBloomFilter::union(
  self : ConcurrentScalableBloomFilter,
  other : ScalableBloomFilter,
) -> ScalableBloomFilter {
  self.with_lock(filter => filter.union(other))
}

///|
/// Whether every key reported present by the current filter is also reported
/// present by `other`, while holding the lock once.
///
/// The other filter must share the initial capacity and target rate.
pub fn ConcurrentScalableBloomFilter::is_subset_of(
  self : ConcurrentScalableBloomFilter,
  other : ScalableBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_subset_of(other))
}

///|
/// Return a consistent copy of the underlying filter, including every slice.
pub fn ConcurrentScalableBloomFilter::snapshot(
  self : ConcurrentScalableBloomFilter,
) -> ScalableBloomFilter {
  self.with_lock(filter => filter.copy())
}

///|
/// Reset the filter to a single empty slice.
pub fn ConcurrentScalableBloomFilter::clear(
  self : ConcurrentScalableBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of insertions observed since creation or the last `clear`.
pub fn ConcurrentScalableBloomFilter::count(
  self : ConcurrentScalableBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether no insertion has happened since creation or the last `clear`.
pub fn ConcurrentScalableBloomFilter::is_empty(
  self : ConcurrentScalableBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_empty())
}

///|
/// Number of slices currently backing the filter.
pub fn ConcurrentScalableBloomFilter::slice_count(
  self : ConcurrentScalableBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.slice_count())
}

///|
/// Sum of the planned capacities of the current slices.
pub fn ConcurrentScalableBloomFilter::capacity(
  self : ConcurrentScalableBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.capacity())
}

///|
/// Number of addressable bits across all slices.
pub fn ConcurrentScalableBloomFilter::bit_count(
  self : ConcurrentScalableBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.bit_count())
}

///|
/// Number of bits currently set to one across all slices.
pub fn ConcurrentScalableBloomFilter::set_bit_count(
  self : ConcurrentScalableBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.set_bit_count())
}

///|
/// Fraction of addressable bits currently set to one.
pub fn ConcurrentScalableBloomFilter::fill_ratio(
  self : ConcurrentScalableBloomFilter,
) -> Double {
  self.with_lock(filter => filter.fill_ratio())
}

///|
/// Estimate the number of distinct keys represented by the current set bits.
pub fn ConcurrentScalableBloomFilter::estimated_item_count(
  self : ConcurrentScalableBloomFilter,
) -> Double {
  self.with_lock(filter => filter.estimated_item_count())
}

///|
/// Target false-positive rate requested at construction time.
pub fn ConcurrentScalableBloomFilter::target_false_positive_rate(
  self : ConcurrentScalableBloomFilter,
) -> Double {
  self.with_lock(filter => filter.target_false_positive_rate())
}

///|
/// Estimated current false-positive rate across all slices.
pub fn ConcurrentScalableBloomFilter::false_positive_rate(
  self : ConcurrentScalableBloomFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}

///|
/// Number of bytes occupied by the bit arrays of all slices.
pub fn ConcurrentScalableBloomFilter::memory_bytes(
  self : ConcurrentScalableBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}

///|
/// Encode the underlying filter as a portable byte sequence while holding the
/// lock.
pub fn ConcurrentScalableBloomFilter::to_bytes(
  self : ConcurrentScalableBloomFilter,
) -> Bytes {
  self.with_lock(filter => filter.to_bytes())
}

///|
/// Restore a thread-safe scalable filter from data produced by `to_bytes`.
///
/// Panics if the data is invalid, just like `ScalableBloomFilter::from_bytes`.
pub fn ConcurrentScalableBloomFilter::from_bytes(
  data : Bytes,
) -> ConcurrentScalableBloomFilter {
  {
    state: @ref.Ref(ScalableBloomFilter::from_bytes(data)),
    mutex: mutex_new(),
  }
}
