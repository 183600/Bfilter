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

Batch helpers insert or test multiple keys:

```moonbit
let keys = ["red", "green", "blue"]
filter.insert_all(keys)
assert_true(filter.contains_all(keys))
filter.clear()
assert_true(filter.is_empty())
```

Bloom filters do not support deletion. Inserting the same key repeatedly is
allowed and increments `count()` each time.

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
entries. `insert_all` and `remove_all` continue after a failure and report
whether every operation succeeded.

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
insertion, deletion round trips, and the concurrent wrapper:

```bash
moon bench --release
```

To run tests on every backend:

```bash
moon test --target all
```
