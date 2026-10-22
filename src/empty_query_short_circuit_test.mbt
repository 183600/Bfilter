///|
/// A key whose custom `Hash` implementation counts how often the filter asks
/// for its hash. Empty and full fast paths must not touch this counter.
struct HashProbe(Int32)

///|
let hash_probe_calls : @ref.Ref[Int32] = @ref.Ref(0)

///|
impl Hash for HashProbe with fn hash_combine(self, hasher) {
  hash_probe_calls.val = hash_probe_calls.val + 1
  hasher.combine_int(self.0)
}

///|
impl Hash for HashProbe with fn hash(self) {
  self.0
}

///|
test "empty filter queries do not hash their keys" {
  let bloom = @src.BloomFilter::with_size(1024, 4)
  let counting = @src.CountingBloomFilter::with_size(1024, 4)
  let compact = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let blocked = @src.BlockedBloomFilter::with_size(1024, 4)
  let cuckoo = @src.CuckooFilter::with_size(16, 4)
  let scalable = @src.ScalableBloomFilter::new(4, 0.01)
  let scalable_counting = @src.ScalableCountingBloomFilter::new(4, 0.01)
  let key = HashProbe(7)
  hash_probe_calls.val = 0
  assert_false(bloom.contains(key))
  assert_false(counting.contains(key))
  assert_eq(counting.count_of(key), 0)
  assert_false(counting.remove(key))
  assert_false(compact.contains(key))
  assert_eq(compact.count_of(key), 0)
  assert_false(compact.remove(key))
  assert_false(blocked.contains(key))
  assert_false(cuckoo.contains(key))
  assert_eq(cuckoo.count_of(key), 0)
  assert_false(cuckoo.remove(key))
  assert_false(scalable.contains(key))
  assert_false(scalable_counting.contains(key))
  assert_eq(hash_probe_calls.val, 0)
}

///|
test "full cuckoo filter conditional insertion does not hash its key" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert(HashProbe(1)))
  assert_true(filter.is_full())
  hash_probe_calls.val = 0
  assert_false(filter.insert_if_absent(HashProbe(2)))
  assert_eq(hash_probe_calls.val, 0)
}

///|
test "empty cuckoo filter answers queries and removals without state changes" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  let before = filter.to_bytes()
  assert_false(filter.contains("absent"))
  assert_eq(filter.count_of("absent"), 0)
  assert_false(filter.remove("absent"))
  assert_eq(filter.to_bytes(), before)

  assert_true(filter.insert("present"))
  assert_true(filter.remove("present"))
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("present"))
  assert_eq(filter.count_of("present"), 0)
  assert_false(filter.remove("present"))
}

///|
test "full cuckoo filter rejects conditional insertion without changing state" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert("only"))
  assert_true(filter.is_full())
  let before = filter.to_bytes()
  let count = filter.count()
  assert_false(filter.insert_if_absent("another"))
  assert_eq(filter.count(), count)
  assert_eq(filter.to_bytes(), before)
  assert_true(filter.contains("only"))
}

///|
test "cleared scalable filters answer empty queries" {
  let bloom = @src.ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    bloom.insert(i)
  }
  assert_true(bloom.slice_count() > 1)
  bloom.clear()
  assert_eq(bloom.count(), 0)
  assert_eq(bloom.slice_count(), 1)
  assert_false(bloom.contains("absent"))
  assert_false(bloom.contains_all(["absent", "missing"]))
  assert_false(bloom.contains_any(["absent", "missing"]))

  let counting = @src.ScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    counting.insert(i)
  }
  assert_true(counting.slice_count() > 1)
  counting.clear()
  assert_eq(counting.count(), 0)
  assert_eq(counting.slice_count(), 1)
  assert_eq(counting.tracked_key_count(), 0)
  assert_false(counting.contains("absent"))
  assert_eq(counting.count_of("absent"), 0)
  assert_false(counting.remove("absent"))
}
