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
/// Test every key in `keys` while holding the lock once.
pub fn[K : Hash] ConcurrentBloomFilter::contains_all(
  self : ConcurrentBloomFilter,
  keys : ArrayView[K],
) -> Bool {
  self.with_lock(filter => filter.contains_all(keys))
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
/// Estimated false-positive rate for the current insertion count.
pub fn ConcurrentBloomFilter::false_positive_rate(
  self : ConcurrentBloomFilter,
) -> Double {
  self.with_lock(filter => filter.false_positive_rate())
}
