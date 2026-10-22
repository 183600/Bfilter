///|
/// A thread-safe Bloom filter.
///
/// Every operation acquires the same mutex, so inserts, queries, and resets
/// observe a consistent filter on native targets. On the JavaScript and
/// WebAssembly backends the mutex is a zero-cost no-op because those runtimes
/// execute a module on a single thread.
///
/// Example:
///
/// ```mbt check
/// test {
///   let filter = @src.ConcurrentBloomFilter::new(100, 0.01)
///   filter.insert("hello")
///   assert_true(filter.contains("hello"))
/// }
/// ```
pub struct ConcurrentBloomFilter {
  priv state : @ref.Ref[BloomFilter]
  priv mutex : Mutex
}

///|
/// Create a thread-safe Bloom filter sized for `expected_items` and the
/// requested false-positive rate.
pub fn ConcurrentBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ConcurrentBloomFilter {
  {
    state: @ref.Ref(BloomFilter::new(expected_items, false_positive_rate)),
    mutex: mutex_new(),
  }
}

///|
/// Create a thread-safe Bloom filter with an explicit bit and hash count.
pub fn ConcurrentBloomFilter::with_size(
  bit_count : Int32,
  hash_count : Int32,
) -> ConcurrentBloomFilter {
  {
    state: @ref.Ref(BloomFilter::with_size(bit_count, hash_count)),
    mutex: mutex_new(),
  }
}

///|
/// Compute the layout that `ConcurrentBloomFilter::new` would use without
/// allocating a backing array.
pub fn ConcurrentBloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  BloomFilter::optimal_size(expected_items, false_positive_rate)
}

///|
fn[R] ConcurrentBloomFilter::with_lock(
  self : ConcurrentBloomFilter,
  f : (BloomFilter) -> R,
) -> R {
  mutex_acquire(self.mutex)
  defer mutex_release(self.mutex)
  f(self.state.val)
}

///|
/// Insert a key. The operation is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentBloomFilter::insert(
  self : ConcurrentBloomFilter,
  key : K,
) -> Unit {
  self.with_lock(filter => filter.insert(key))
}

///|
/// Insert a key only when it is definitely absent. The check and insertion are
/// atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentBloomFilter::insert_if_absent(
  self : ConcurrentBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert_if_absent(key))
}

///|
/// Test whether a key may be present.
pub fn[K : Hash] ConcurrentBloomFilter::contains(
  self : ConcurrentBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.contains(key))
}

///|
/// Insert every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentBloomFilter::insert_all(
  self : ConcurrentBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  self.with_lock(filter => filter.insert_all(keys))
}

///|
/// Insert every key that is definitely absent while holding the lock once and
/// return how many were added.
pub fn[K : Hash] ConcurrentBloomFilter::insert_all_if_absent(
  self : ConcurrentBloomFilter,
  keys : ArrayView[K],
) -> Int32 {
  self.with_lock(filter => filter.insert_all_if_absent(keys))
}

///|
/// Merge another filter into this one while holding the lock once.
///
/// The other filter must use the same bit and hash counts. Its bits are
/// combined with the current state and its insertion count is added.
pub fn ConcurrentBloomFilter::merge(
  self : ConcurrentBloomFilter,
  other : BloomFilter,
) -> Unit {
  self.with_lock(filter => filter.merge(other))
}

///|
/// Build a filter containing every key present in either input while holding
/// the lock once.
///
/// The other filter must use the same bit and hash counts. The result is an
/// independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentBloomFilter::union(
  self : ConcurrentBloomFilter,
  other : BloomFilter,
) -> BloomFilter {
  self.with_lock(filter => filter.union(other))
}

///|
/// Build a filter containing only the keys reported present by both inputs
/// while holding the lock once.
///
/// The other filter must use the same bit and hash counts. The result is an
/// independent filter; the concurrent receiver is left unchanged.
pub fn ConcurrentBloomFilter::intersection(
  self : ConcurrentBloomFilter,
  other : BloomFilter,
) -> BloomFilter {
  self.with_lock(filter => filter.intersection(other))
}

///|
/// Whether every bit set in the current filter is also set in `other`, while
/// holding the lock once.
///
/// The other filter must use the same bit and hash counts.
pub fn ConcurrentBloomFilter::is_subset_of(
  self : ConcurrentBloomFilter,
  other : BloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_subset_of(other))
}

///|
/// Whether the current filter and `other` are definitely disjoint, while
/// holding the lock once.
///
/// The other filter must use the same bit and hash counts.
pub fn ConcurrentBloomFilter::is_disjoint_from(
  self : ConcurrentBloomFilter,
  other : BloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_disjoint_from(other))
}

///|
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentBloomFilter::contains_all(
  self : ConcurrentBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
}

///|
/// Test whether at least one key in `keys` may be present while holding the
/// lock once.
pub fn[K : Hash] ConcurrentBloomFilter::contains_any(
  self : ConcurrentBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_any(keys))
}

///|
/// Return a consistent copy of the underlying filter.
///
/// The copy is independent, so it can be queried without holding the lock
/// while other threads continue to update the concurrent filter.
pub fn ConcurrentBloomFilter::snapshot(
  self : ConcurrentBloomFilter,
) -> BloomFilter {
  self.with_lock(filter => filter.copy())
}

///|
/// Remove all inserted keys from the filter.
pub fn ConcurrentBloomFilter::clear(self : ConcurrentBloomFilter) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of insertions observed since the filter was created or cleared.
pub fn ConcurrentBloomFilter::count(self : ConcurrentBloomFilter) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether no key has been inserted since the filter was created or cleared.
pub fn ConcurrentBloomFilter::is_empty(self : ConcurrentBloomFilter) -> Bool {
  self.with_lock(filter => filter.is_empty())
}

///|
/// Number of addressable bits in the underlying filter.
pub fn ConcurrentBloomFilter::bit_count(self : ConcurrentBloomFilter) -> Int32 {
  self.with_lock(filter => filter.bit_count())
}

///|
/// Number of hash functions applied per operation.
pub fn ConcurrentBloomFilter::hash_count(self : ConcurrentBloomFilter) -> Int32 {
  self.with_lock(filter => filter.hash_count())
}

///|
/// Number of bits currently set to one.
pub fn ConcurrentBloomFilter::set_bit_count(
  self : ConcurrentBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.set_bit_count())
}

///|
/// Fraction of addressable bits currently set to one.
pub fn ConcurrentBloomFilter::fill_ratio(
  self : ConcurrentBloomFilter,
) -> Double {
  self.with_lock(filter => filter.fill_ratio())
}

///|
/// Estimate the number of distinct keys represented by the current set bits.
pub fn ConcurrentBloomFilter::estimated_item_count(
  self : ConcurrentBloomFilter,
) -> Double {
  self.with_lock(filter => filter.estimated_item_count())
}

///|
/// Number of bytes occupied by the underlying bit array.
pub fn ConcurrentBloomFilter::memory_bytes(
  self : ConcurrentBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}

///|
/// Estimated false-positive rate for the current insertion count.
pub fn ConcurrentBloomFilter::false_positive_rate(
  self : ConcurrentBloomFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}

///|
/// Encode the underlying filter as a portable byte sequence while holding the
/// lock.
pub fn ConcurrentBloomFilter::to_bytes(self : ConcurrentBloomFilter) -> Bytes {
  self.with_lock(filter => filter.to_bytes())
}

///|
/// Restore a thread-safe Bloom filter from data produced by `to_bytes`.
///
/// Panics if the data is invalid, just like `BloomFilter::from_bytes`.
pub fn ConcurrentBloomFilter::from_bytes(data : Bytes) -> ConcurrentBloomFilter {
  { state: @ref.Ref(BloomFilter::from_bytes(data)), mutex: mutex_new(), }
}
