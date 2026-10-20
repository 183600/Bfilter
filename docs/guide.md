# Bfilter User Guide

Bfilter provides probabilistic set data structures for MoonBit. All filters
accept any key type that implements `Hash`, including `String`, integers, and
user-defined types with a `Hash` implementation.

## Quick Start

```moonbit
let filter = @src.BloomFilter::new(1000, 0.01)
filter.insert("alpha")
filter.insert("beta")

assert_true(filter.contains("alpha"))
assert_false(filter.contains("gamma"))
```

`contains` never returns `false` for a successfully inserted key. It can
return `true` for a key that was never inserted; the probability is controlled
by the requested false-positive rate.

## Bloom Filter

`BloomFilter::new(expected_items, false_positive_rate)` sizes the filter from
the standard Bloom filter formulas. `BloomFilter::with_size(bit_count,
hash_count)` is available when a configuration is already known.

```moonbit
let filter = @src.BloomFilter::new(10_000, 0.001)
for i = 0; i < 10_000; i = i + 1 {
  filter.insert(i)
}
assert_true(filter.contains(123))
assert_true(filter.false_positive_rate() < 0.01)
```

Storage is bit-packed: the filter uses approximately `bit_count / 8` bytes.
`bit_count()` reports the rounded-up number of addressable bits, and
`false_positive_rate()` estimates the current rate from the insertion count.

Batch helpers insert or test multiple keys. `contains_all` requires every key,
while `contains_any` stops at the first possible match and returns `false` for
an empty batch:

```moonbit
let keys = ["red", "green", "blue"]
filter.insert_all(keys)
assert_true(filter.contains_all(keys))
assert_true(filter.contains_any(["missing", "red"]))
filter.clear()
assert_true(filter.is_empty())
```

All filter types and their concurrent wrappers expose the same batch helpers.

Bloom filters do not support deletion. Inserting the same key repeatedly is
allowed and increments `count()` each time. `insert_if_absent(key)` inserts
only when at least one selected bit is unset, returning `true` on insertion and
`false` when the key may already be present:

```moonbit
let filter = @src.BloomFilter::new(1000, 0.01)
assert_true(filter.insert_if_absent("once"))
assert_false(filter.insert_if_absent("once"))
assert_eq(filter.count(), 1)
```

False positives can suppress an insertion that would otherwise be harmless.
The counting and cuckoo variants provide the same method, and the concurrent
wrappers make the check and insertion atomic. `insert_all_if_absent(keys)`
applies the check to a batch and returns the number of keys actually added.

Filters with identical `bit_count()` and `hash_count()` can be combined.
`union` returns a filter that reports keys from either input, `intersection`
returns one that reports keys from both, and `is_subset_of` checks whether every
bit of one filter is present in another:

```moonbit
let left = @src.BloomFilter::with_size(4096, 4)
let right = @src.BloomFilter::with_size(4096, 4)
left.insert("left")
right.insert("right")
let combined = left.union(right)
assert_true(combined.contains("left"))
assert_true(combined.contains("right"))
assert_true(left.is_subset_of(combined))
```

The combined filter's `count()` is an upper bound: `union` adds the input
counts and `intersection` takes the smaller one, so `false_positive_rate()`
stays conservative when the inputs overlap. These operations panic when the
filter configurations differ.

`merge` performs the same combination as `union` in place, avoiding a new
allocation. The concurrent wrappers expose `merge`, `union`, `intersection`,
and `is_subset_of`, acquiring the lock once for the whole operation:

```moonbit
let target = @src.BloomFilter::with_size(4096, 4)
target.insert("target")
target.merge(combined)
assert_true(target.contains("left"))
assert_true(target.contains("target"))
```

## Scalable Bloom Filter

`ScalableBloomFilter` starts with one Bloom filter slice sized for an initial
capacity. When the newest slice reaches its planned capacity, the filter adds a
new slice with twice the capacity and half the false-positive budget. Existing
keys stay in the slice where they were inserted, and queries check every slice.

```moonbit
let filter = @src.ScalableBloomFilter::new(100, 0.01)
for i = 0; i < 1000; i = i + 1 {
  filter.insert(i)
}
assert_true(filter.slice_count() > 1)
assert_true(filter.contains(42))
assert_eq(filter.count(), 1000)
assert_true(filter.target_false_positive_rate() == 0.01)
assert_true(filter.false_positive_rate() < 0.01)
```

`insert_if_absent` checks all slices before inserting into the newest one.
`capacity()` reports the sum of the current slice capacities, while
`bit_count()`, `set_bit_count()`, `fill_ratio()`, and `memory_bytes()` aggregate
the slices. `copy` is independent, and `clear` returns the filter to a single
empty slice with the original initial capacity. `ConcurrentScalableBloomFilter`
provides the same operations with one mutex and a `snapshot()` method.

## Counting Bloom Filter

`CountingBloomFilter` stores a 16-bit counter per slot, allowing one insertion
of a key to be removed at a time.

```moonbit
let filter = @src.CountingBloomFilter::new(1000, 0.01)
filter.insert("task")
filter.insert("task")
assert_eq(filter.count(), 2)

assert_true(filter.remove("task"))
assert_true(filter.contains("task"))
assert_true(filter.remove("task"))
assert_false(filter.contains("task"))
```

Counters saturate at 65535. Removing a key that was never inserted can return
`true` on a false positive and disturb other entries, so only remove keys that
are known to be present. `remove_all` returns `true` only if every removal
succeeded; it continues removing the remaining keys after a failure.

`count_of(key)` estimates the current multiplicity of a key by taking the
smallest counter it selects. Other keys that share those slots can make the
estimate too high, but it never drops below the number of insertions unless a
counter has saturated:

```moonbit
let filter = @src.CountingBloomFilter::new(1000, 0.01)
filter.insert("task")
filter.insert("task")
assert_eq(filter.count_of("task"), 2)
assert_true(filter.remove("task"))
assert_eq(filter.count_of("task"), 1)
```

`insert_if_absent(key)` inserts only when at least one selected counter is
zero; it returns `false` without changing the filter when the key may already
be present.

Counting filters with identical `slot_count()` and `hash_count()` support the
same set algebra as Bloom filters, with counters merged per slot. `union` takes
the larger counter and preserves the larger multiplicity of duplicate keys,
`intersection` takes the smaller counter, and `is_subset_of` checks every
counter:

```moonbit
let left = @src.CountingBloomFilter::with_size(4096, 4)
let right = @src.CountingBloomFilter::with_size(4096, 4)
left.insert("left")
right.insert("right")
let combined = left.union(right)
assert_true(combined.contains("left"))
assert_true(combined.contains("right"))
assert_true(left.is_subset_of(combined))
```

As with Bloom filters, the combined `count()` is conservative: `union` adds the
input counts and `intersection` takes the smaller one. These operations panic
when the filter configurations differ. `merge` applies the same counter
combination to an existing filter in place, and the concurrent wrapper exposes
atomic `merge`, `union`, `intersection`, and `is_subset_of` methods that hold
the lock once.

## Cuckoo Filter

`CuckooFilter` stores one-byte fingerprints in two candidate buckets per key.
It supports deletion and typically uses less memory than a counting Bloom
filter at comparable false-positive rates.

```moonbit
let filter = @src.CuckooFilter::new(10_000)
assert_true(filter.insert("session-1"))
assert_true(filter.contains("session-1"))
assert_true(filter.remove("session-1"))
assert_false(filter.contains("session-1"))
```

`with_size(bucket_count, bucket_size)` exposes the physical layout. The bucket
count is rounded up to a power of two, which is required for alternate-index
calculation. `insert` returns `false` when the filter is full and restores all
evicted fingerprints before returning, so a failed insert cannot lose existing
entries. Before reporting a filter as full, insertion also searches for an
augmenting path that moves existing fingerprints to their alternate buckets;
this succeeds whenever a valid placement is reachable within the bounded
search. `insert_all` and `remove_all` continue after a failure and report
whether every operation succeeded.

`count_of(key)` counts matching fingerprints in the key's two candidate
buckets. Duplicate insertions are therefore observable, and the count decreases
as copies are removed. `insert_if_absent(key)` returns `false` when the
fingerprint is already present or when the filter has no room for it.

Filters with the same bucket layout can be combined. `union` copies the
fingerprints of both inputs and returns `None` if the combined entries do not
fit, leaving both inputs unchanged:

```moonbit
let left = @src.CuckooFilter::with_size(64, 4)
let right = @src.CuckooFilter::with_size(64, 4)
assert_true(left.insert("left"))
assert_true(right.insert("right"))
match left.union(right) {
  Some(combined) => assert_true(combined.contains_all(["left", "right"]))
  None => abort("combined filter is full")
}
```

`merge` applies the union to an existing filter and returns `false` without
changing it when the entries do not fit. `ConcurrentCuckooFilter::merge`,
`union`, `intersection`, and `is_subset_of` hold the lock once while performing
the same operations.

`intersection` returns a filter containing only the fingerprints present in both
inputs, keeping the smaller multiplicity for each candidate pair. Because a key
can live in either of its two candidate buckets, the operation counts each
unordered candidate pair, so a key that both inputs report is never dropped even
when the two filters stored it in different buckets. The result always fits and
its `count()` never exceeds either input's count:

```moonbit
let shared_left = @src.CuckooFilter::with_size(64, 4)
let shared_right = @src.CuckooFilter::with_size(64, 4)
assert_true(shared_left.insert_all(["keep", "left-only"]))
assert_true(shared_right.insert_all(["keep", "right-only"]))
let common = shared_left.intersection(shared_right)
assert_true(common.contains("keep"))
assert_false(common.contains("left-only"))
assert_false(common.contains("right-only"))
```

`is_subset_of` compares fingerprints across each key's two candidate buckets
and respects duplicate multiplicities, so a `true` result means every key
reported by the first filter is also reported by the second:

```moonbit
assert_true(left.is_subset_of(combined))
assert_true(right.is_subset_of(combined))
```

## Concurrent Bloom Filter

`ConcurrentBloomFilter` wraps a `BloomFilter` and serializes every operation
with a mutex.

```moonbit
let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
filter.insert("shared")
assert_true(filter.contains("shared"))

let keys = ["a", "b", "c"]
filter.insert_all(keys)
assert_true(filter.contains_all(keys))
```

On native and LLVM targets the mutex is an operating-system mutex backed by the
runtime's C stub. On JavaScript, WebAssembly, and WebAssembly GC targets the
mutex is a no-op because a module executes on a single thread. Batch operations
hold the lock once for the whole batch.

`ConcurrentCountingBloomFilter` provides the same protection around a
`CountingBloomFilter`, including atomic `remove` and `remove_all` operations:

```moonbit
let filter = @src.ConcurrentCountingBloomFilter::new(1000, 0.01)
filter.insert("shared")
assert_true(filter.remove("shared"))
assert_false(filter.contains("shared"))
```

`ConcurrentCuckooFilter` wraps a `CuckooFilter` in the same way. `insert`,
`remove`, and the batch variants keep their boolean result while acquiring the
lock exactly once:

```moonbit
let filter = @src.ConcurrentCuckooFilter::new(1000)
assert_true(filter.insert("session"))
assert_true(filter.contains("session"))
assert_true(filter.remove("session"))
```

Each filter type also has `copy()`, which returns an independent filter. The
concurrent wrappers expose `snapshot()`, which copies the underlying filter
while holding the lock. A snapshot remains unchanged if other threads keep
updating the original:

```moonbit
let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
filter.insert("before")
let snapshot = filter.snapshot()
filter.insert("after")
assert_eq(snapshot.count(), 1)
assert_true(snapshot.contains("before"))
```

## Occupancy and Storage

Every filter exposes read-only statistics without scanning keys:

- `BloomFilter::set_bit_count()` counts the bits set to one, while
  `fill_ratio()` divides that count by `bit_count()`.
- `CountingBloomFilter::occupied_slot_count()` counts slots with a positive
  counter, while `fill_ratio()` divides that count by `slot_count()`.
- `CuckooFilter::load_factor()` divides the stored fingerprint count by the
  total number of slots, which is reported by `capacity()`.
- `estimated_item_count()` derives the number of distinct keys from occupancy
  for the Bloom variants; the scalable variant sums its slice estimates. It returns infinity when every slot is occupied.
- `CuckooFilter::false_positive_rate()` estimates the current rate from the
  average bucket occupancy and the eight-bit fingerprint size.
- `memory_bytes()` reports the size of the backing array.

The concurrent wrappers expose the same methods and acquire the mutex before
reading. For example:

```moonbit
let filter = @src.BloomFilter::new(1000, 0.01)
filter.insert("value")
let ratio = filter.fill_ratio()
assert_true(ratio > 0.0 && ratio <= 1.0)
```

## Serialization

Every filter can be encoded to `Bytes` with `to_bytes()` and restored with
`from_bytes()`. The format stores the configuration, insertion count, and
backing array, and is versioned with a type tag:

```moonbit
let filter = @src.BloomFilter::new(1000, 0.01)
filter.insert("saved")
let data = filter.to_bytes()
let restored = @src.BloomFilter::from_bytes(data)
assert_true(restored.contains("saved"))
```

The same methods exist on `CountingBloomFilter`, `CuckooFilter`, and
`ScalableBloomFilter`. The concurrent wrappers also expose `to_bytes()` and
`from_bytes()`, copying the underlying filter while holding the lock. Hashing uses fixed seeds, so standard
`Hash` implementations produce the same positions in a new process.
`from_bytes` panics on truncated data, a different filter type, an unsupported
version, or an invalid configuration.

## Configuration and Errors

Constructors panic on invalid arguments:

- `expected_items` and `bit_count`/`slot_count`/`bucket_count` must be positive.
- `false_positive_rate` must satisfy `0 < rate < 1`.
- `hash_count` and `bucket_size` must be positive.
- Requests that would overflow the supported index or storage sizes panic
  instead of silently wrapping.

For a target false-positive rate `p` and `n` expected items, Bloom filters need
roughly `-n * ln(p) / (ln 2)^2` bits and `-log2(p)` hash functions. Passing a
larger `n` than the actual workload lowers the false-positive rate; passing a
smaller one raises it, as shown by `false_positive_rate()`.

## Testing and Benchmarks

Run the full unit suite:

```bash
moon check
moon test
```

Benchmarks live in `src/benchmark_test.mbt` and cover insertion, queries, batch
insertion, conditional insertion, multiplicity queries, deletion round trips,
set operations, and the concurrent wrapper:

```bash
moon bench --release
```

To run tests on every backend:

```bash
moon test --target all
```
