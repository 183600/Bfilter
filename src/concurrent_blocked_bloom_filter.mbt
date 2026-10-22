///|
/// A thread-safe blocked Bloom filter.
///
/// Every operation acquires the same mutex, so inserts, queries, and resets
/// observe a consistent filter on native targets. On the JavaScript and
/// WebAssembly backends the mutex is a zero-cost no-op because those runtimes
/// execute a module on a single thread.
pub struct ConcurrentBlockedBloomFilter {
  priv state : @ref.Ref[BlockedBloomFilter]
  priv mutex : Mutex
}

///|
/// Create a thread-safe blocked filter sized for `expected_items` and the
/// requested false-positive rate.
pub fn ConcurrentBlockedBloomFilter::new(
  expected_items : Int32,
  false_positive_rate : Double,
) -> ConcurrentBlockedBloomFilter {
  {
    state: @ref.Ref(
      BlockedBloomFilter::new(expected_items, false_positive_rate),
    ),
    mutex: mutex_new(),
  }
}

///|
/// Create a thread-safe blocked filter with an explicit bit and hash count.
pub fn ConcurrentBlockedBloomFilter::with_size(
  bit_count : Int32,
  hash_count : Int32,
) -> ConcurrentBlockedBloomFilter {
  {
    state: @ref.Ref(BlockedBloomFilter::with_size(bit_count, hash_count)),
    mutex: mutex_new(),
  }
}

///|
/// Compute the layout that `ConcurrentBlockedBloomFilter::new` would use without
/// allocating a backing array.
pub fn ConcurrentBlockedBloomFilter::optimal_size(
  expected_items : Int32,
  false_positive_rate : Double,
) -> (Int32, Int32) {
  BlockedBloomFilter::optimal_size(expected_items, false_positive_rate)
}

///|
fn[R] ConcurrentBlockedBloomFilter::with_lock(
  self : ConcurrentBlockedBloomFilter,
  f : (BlockedBloomFilter) -> R,
) -> R {
  mutex_acquire(self.mutex)
  defer mutex_release(self.mutex)
  f(self.state.val)
}

///|
/// Insert a key. The operation is atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentBlockedBloomFilter::insert(
  self : ConcurrentBlockedBloomFilter,
  key : K,
) -> Unit {
  self.with_lock(filter => filter.insert(key))
}

///|
/// Insert a key only when it is definitely absent. The check and insertion are
/// atomic with respect to the other methods.
pub fn[K : Hash] ConcurrentBlockedBloomFilter::insert_if_absent(
  self : ConcurrentBlockedBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.insert_if_absent(key))
}

///|
/// Test whether a key may be present.
pub fn[K : Hash] ConcurrentBlockedBloomFilter::contains(
  self : ConcurrentBlockedBloomFilter,
  key : K,
) -> Bool {
  self.with_lock(filter => filter.contains(key))
}

///|
/// Insert every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentBlockedBloomFilter::insert_all(
  self : ConcurrentBlockedBloomFilter,
  keys : ArrayView[K],
) -> Unit {
  self.with_lock(filter => filter.insert_all(keys))
}

///|
/// Insert every key that is definitely absent while holding the lock once and
/// return how many were added.
pub fn[K : Hash] ConcurrentBlockedBloomFilter::insert_all_if_absent(
  self : ConcurrentBlockedBloomFilter,
  keys : ArrayView[K],
) -> Int32 {
  self.with_lock(filter => filter.insert_all_if_absent(keys))
}

///|
/// Merge another filter into this one while holding the lock once.
///
/// The other filter must use the same bit and hash counts.
pub fn ConcurrentBlockedBloomFilter::merge(
  self : ConcurrentBlockedBloomFilter,
  other : BlockedBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.merge(other))
}

///|
/// Build a filter containing every key present in either input while holding
/// the lock once.
pub fn ConcurrentBlockedBloomFilter::union(
  self : ConcurrentBlockedBloomFilter,
  other : BlockedBloomFilter,
) -> BlockedBloomFilter {
  self.with_lock(filter => filter.union(other))
}

///|
/// Build a filter containing only the keys reported present by both inputs
/// while holding the lock once.
pub fn ConcurrentBlockedBloomFilter::intersection(
  self : ConcurrentBlockedBloomFilter,
  other : BlockedBloomFilter,
) -> BlockedBloomFilter {
  self.with_lock(filter => filter.intersection(other))
}

///|
/// Whether every bit set in the current filter is also set in `other`, while
/// holding the lock once.
pub fn ConcurrentBlockedBloomFilter::is_subset_of(
  self : ConcurrentBlockedBloomFilter,
  other : BlockedBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_subset_of(other))
}

///|
/// Whether the current filter and `other` are definitely disjoint, while
/// holding the lock once.
pub fn ConcurrentBlockedBloomFilter::is_disjoint_from(
  self : ConcurrentBlockedBloomFilter,
  other : BlockedBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_disjoint_from(other))
}

///|
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentBlockedBloomFilter::contains_all(
  self : ConcurrentBlockedBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
}

///|
/// Test whether at least one key in `keys` may be present while holding the
/// lock once.
pub fn[K : Hash] ConcurrentBlockedBloomFilter::contains_any(
  self : ConcurrentBlockedBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_any(keys))
}

///|
/// Return an independent copy of the underlying filter.
///
/// This is equivalent to `snapshot()` and acquires the lock while copying.
pub fn ConcurrentBlockedBloomFilter::copy(
  self : ConcurrentBlockedBloomFilter,
) -> BlockedBloomFilter {
  self.with_lock(filter => filter.copy())
}

///|
/// Return a consistent copy of the underlying filter.
///
/// The copy is independent, so it can be queried without holding the lock
/// while other threads continue to update the concurrent filter.
pub fn ConcurrentBlockedBloomFilter::snapshot(
  self : ConcurrentBlockedBloomFilter,
) -> BlockedBloomFilter {
  self.copy()
}

///|
/// Remove all inserted keys from the filter.
pub fn ConcurrentBlockedBloomFilter::clear(
  self : ConcurrentBlockedBloomFilter,
) -> Unit {
  self.with_lock(filter => filter.clear())
}

///|
/// Number of insertions observed since the filter was created or cleared.
pub fn ConcurrentBlockedBloomFilter::count(
  self : ConcurrentBlockedBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.count())
}

///|
/// Whether no key has been inserted since the filter was created or cleared.
pub fn ConcurrentBlockedBloomFilter::is_empty(
  self : ConcurrentBlockedBloomFilter,
) -> Bool {
  self.with_lock(filter => filter.is_empty())
}

///|
/// Number of addressable bits in the underlying filter.
pub fn ConcurrentBlockedBloomFilter::bit_count(
  self : ConcurrentBlockedBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.bit_count())
}

///|
/// Number of whole 512-bit blocks in the underlying filter.
pub fn ConcurrentBlockedBloomFilter::block_count(
  self : ConcurrentBlockedBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.block_count())
}

///|
/// Number of hash functions applied per operation.
pub fn ConcurrentBlockedBloomFilter::hash_count(
  self : ConcurrentBlockedBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.hash_count())
}

///|
/// Number of bits currently set to one.
pub fn ConcurrentBlockedBloomFilter::set_bit_count(
  self : ConcurrentBlockedBloomFilter,
) -> Int32 {
  self.with_lock(filter => filter.set_bit_count())
}

///|
/// Fraction of addressable bits currently set to one.
pub fn ConcurrentBlockedBloomFilter::fill_ratio(
  self : ConcurrentBlockedBloomFilter,
) -> Double {
  self.with_lock(filter => filter.fill_ratio())
}

///|
/// Estimate the number of distinct keys represented by the current set bits.
pub fn ConcurrentBlockedBloomFilter::estimated_item_count(
  self : ConcurrentBlockedBloomFilter,
) -> Double {
  self.with_lock(filter => filter.estimated_item_count())
}

///|
/// Number of bytes occupied by the underlying bit array.
pub fn ConcurrentBlockedBloomFilter::memory_bytes(
  self : ConcurrentBlockedBloomFilter,
) -> Int64 {
  self.with_lock(filter => filter.memory_bytes())
}

///|
/// Estimated false-positive rate for the current insertion count.
pub fn ConcurrentBlockedBloomFilter::false_positive_rate(
  self : ConcurrentBlockedBloomFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}

///|
/// Encode the underlying filter while holding the lock.
pub fn ConcurrentBlockedBloomFilter::to_bytes(
  self : ConcurrentBlockedBloomFilter,
) -> Bytes {
  self.with_lock(filter => filter.to_bytes())
}

///|
/// Restore a thread-safe blocked filter from data produced by `to_bytes`.
///
/// Panics if the data is invalid, just like `BlockedBloomFilter::from_bytes`.
pub fn ConcurrentBlockedBloomFilter::from_bytes(
  data : Bytes,
) -> ConcurrentBlockedBloomFilter {
  { state: @ref.Ref(BlockedBloomFilter::from_bytes(data)), mutex: mutex_new(), }
}
