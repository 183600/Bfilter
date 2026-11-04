# Bfilter User Guide

Bfilter provides probabilistic set data structures for MoonBit. Every filter
accepts any key type that implements `Hash`, such as `String`, integers, or
user-defined types with a `Hash` implementation.

## Table of Contents

- [Quick Start](#quick-start)
- [Choosing a Filter](#choosing-a-filter)
- [Core Concepts](#core-concepts)
- [Filter Types](#filter-types)
  - [Bloom Filter](#bloom-filter)
  - [Blocked Bloom Filter](#blocked-bloom-filter)
  - [Counting Bloom Filter](#counting-bloom-filter)
  - [Compact Counting Bloom Filter](#compact-counting-bloom-filter)
  - [Scalable Bloom Filter](#scalable-bloom-filter)
  - [Scalable Counting Bloom Filter](#scalable-counting-bloom-filter)
  - [Cuckoo Filter](#cuckoo-filter)
- [Concurrent Wrappers](#concurrent-wrappers)
- [Set Operations](#set-operations)
- [Serialization](#serialization)
- [Sizing Before Allocation](#sizing-before-allocation)
- [Performance Characteristics](#performance-characteristics)
- [Configuration and Errors](#configuration-and-errors)
- [Testing and Benchmarks](#testing-and-benchmarks)

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

## Choosing a Filter

| Requirement | Recommended Filter | Deletion | Memory (per item) |
| --- | --- | --- | --- |
| Minimum memory, no deletion | `BloomFilter` | No | ~1.25 bytes |
| High query throughput, cache-friendly | `BlockedBloomFilter` | No | ~1.25 bytes |
| Need deletion & multiplicity | `CountingBloomFilter` | Yes (16-bit) | ~8 bytes |
| Deletion with memory constraints | `CompactCountingBloomFilter` | Yes (4-bit) | ~2 bytes |
| Unbounded insertions, no deletion | `ScalableBloomFilter` | No | Grows dynamically |
| Unbounded insertions with deletion | `ScalableCountingBloomFilter` | Yes (16-bit) | Grows dynamically |
| High load factor, exact deletion | `CuckooFilter` | Yes | ~1 byte |
| Thread-safe access (native/LLVM) | `Concurrent*` wrapper | As wrapped | Same as wrapped |

## Core Concepts

### False Positives and False Negatives

All filters in this library are **probabilistic**: they may report that a key is
present when it was never inserted (false positive), but they **never** report
that an inserted key is absent (no false negatives).

The false-positive rate is controlled at construction time and can be estimated
at runtime with `false_positive_rate()`.

### Hashing

All filters use a fixed-seed hashing scheme. This means:
- Filters serialized with `to_bytes()` can be restored in a different process
  and will produce the same results for the same keys.
- The hash function is derived from the key's `Hash` implementation.

### Batch Operations

Every filter exposes batch helpers for efficiency:

- `insert_all(keys)` — inserts all keys
- `insert_all_if_absent(keys)` — inserts only absent keys, returns count added
- `contains_all(keys)` — returns `true` only if all keys are present
- `contains_any(keys)` — returns `true` if at least one key is present
- `remove_all(keys)` — removes all keys (counting/cuckoo filters only)

Empty batches are no-ops and never touch the backing storage.

## Filter Types

### Bloom Filter

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

**Storage:** Bit-packed; `bit_count()` is always a multiple of 64, so the
backing array uses exactly `bit_count / 8` bytes.

**Optimizations:**
- Empty filter: queries return `false` without probing
- Full filter: detected with one word scan; queries return `true` without probing
- Power-of-two bit counts: wide `hash_count` stops after one double-hash cycle

**Deletion:** Not supported. Repeated insertions increment `count()`.
`insert_if_absent(key)` inserts only when at least one bit is unset.

### Blocked Bloom Filter

`BlockedBloomFilter` keeps every probe for a key inside one 512-bit block, so a
query touches at most one cache line instead of scattering accesses across the
whole bit array.

```moonbit
let filter = @src.BlockedBloomFilter::new(10_000, 0.001)
filter.insert_all(["alpha", "beta"])
assert_true(filter.contains("alpha"))
assert_true(filter.contains_all(["alpha", "beta"]))
assert_eq(filter.bit_count() % 512, 0)
assert_eq(filter.block_count(), filter.bit_count() / 512)
```

**Trade-off:** Blocks fill unevenly, which can raise the observed false-positive
rate slightly above a classic Bloom filter with the same total bit count. The
standard `fill_ratio()`, `estimated_item_count()`, and `false_positive_rate()`
estimates remain available.

**Configuration:** `with_size(bit_count, hash_count)` rounds the bit count up to
whole blocks, so `bit_count()` is always a multiple of 512.

### Counting Bloom Filter

`CountingBloomFilter` stores a 16-bit counter per slot, allowing deletion.

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

**Counters:** Saturate at 65535 (`counter_max()`). A lane selected multiple times
by one key stores a weighted contribution per insertion.

**Multiplicity:** `count_of(key)` estimates current multiplicity from the
counters it selects. The estimate divides the smallest counter by the number of
times the key selects that position.

**Safety:** Removing a key that was never inserted can return `true` on a false
positive and disturb other entries—only remove keys known to be present.

### Compact Counting Bloom Filter

`CompactCountingBloomFilter` packs each counter into a 4-bit nibble, using
~1/4 the memory of `CountingBloomFilter`.

```moonbit
let compact = @src.CompactCountingBloomFilter::new(1000, 0.01)
let regular = @src.CountingBloomFilter::new(1000, 0.01)
assert_eq(regular.memory_bytes(), compact.memory_bytes() * 4L)

compact.insert("task")
compact.insert("task")
assert_eq(compact.count_of("task"), 2)
assert_true(compact.remove("task"))
assert_eq(compact.count_of("task"), 1)
```

**Limitations:**
- Counters saturate at 15 (`counter_max()`)
- Insertions past the cap advance `count()` but leave counters unchanged
- Saturated shared counters couple keys: removing one key can drain another's
  counter, causing false negatives
- Avoid interleaved removals when keys overlap on saturated positions

### Scalable Bloom Filter

`ScalableBloomFilter` starts with one slice and grows by adding slices when the
newest reaches its planned capacity. Each new slice doubles capacity and halves
its false-positive budget.

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

**Key properties:**
- Keys stay in the slice where they were first inserted
- `insert_if_absent` checks all slices before inserting
- `clear` reuses the first slice's backing array and drops later slices
- Set operations (`merge`, `union`, `intersection`, `is_subset_of`,
  `is_disjoint_from`) combine slices by index

**Set operation caveat:** `intersection` only compares slices at matching
indices, so it can omit a key both inputs contain if they placed it in different
slices. Most useful when inputs grew in lockstep.

### Scalable Counting Bloom Filter

`ScalableCountingBloomFilter` combines slice growth with removable counters.
Each key is tracked with its exact multiplicity and owning slice.

```moonbit
let filter = @src.ScalableCountingBloomFilter::new(4, 0.01)
for i = 0; i < 40; i = i + 1 {
  filter.insert("key-" + i.to_string())
}
filter.insert("key-0")
assert_true(filter.slice_count() > 1)
assert_eq(filter.count_of("key-0"), 2)
assert_true(filter.remove("key-0"))
assert_eq(filter.count_of("key-0"), 1)
assert_eq(filter.tracked_key_count(), 40)
```

**Tracking:** A 128-bit hash + multiplicity is stored for each distinct key.
This metadata grows with distinct keys and is **not** included in `memory_bytes()`.
Use `metadata_bytes()` to estimate the approximate size of this location metadata
(24 bytes per distinct key); concurrent wrappers expose the same helper.

**Set operations:**
- `union`/`merge`: rebuild counters from tracked multiplicities; same slice →
  max multiplicity, different slices → sum multiplicities; self-union preserves
  multiplicities
- `intersection`: keeps keys reported by both with smaller multiplicity, even
  across different slices
- `is_subset_of`: consults tracked multiplicities across slices for cross-slice
  keys
- `is_disjoint_from`: compares slice counters directly (no cross-slice fallback)

**Saturation:** Counters still saturate at 65535. After saturation, `count_of`
reports exact tracked multiplicity but `contains` may return `false` and
`remove` returns `false` for remaining occurrences. Use `count_of` for exact
multiplicity past saturation.

### Cuckoo Filter

`CuckooFilter` stores one-byte fingerprints in two candidate buckets per key.
Supports deletion with typically less memory than counting Bloom at comparable
false-positive rates.

```moonbit
let filter = @src.CuckooFilter::new(10_000)
assert_true(filter.insert("session-1"))
assert_true(filter.contains("session-1"))
assert_true(filter.remove("session-1"))
assert_false(filter.contains("session-1"))
```

**Layout:** `with_size(bucket_count, bucket_size)` — bucket count rounded to
power of two for alternate-index calculation.

**Insertion:** May evict fingerprints; runs bounded BFS for augmenting path on
failure. Failed insert restores all evictions. `insert` returns `false` when
full or no placement found.

**Multiplicity:** `count_of(key)` counts matching fingerprints in both candidate
buckets. The result can exceed the true multiplicity when hash collisions occur,
but never falls below the number of successful insertions.

**Capacity:** `capacity()` returns total fingerprints the filter can hold.
`remaining_capacity()` reports how many fingerprints can still be inserted.
A filter can reject an insertion before reaching capacity when no augmenting
path exists. `is_full()` checks whether `inserted >= capacity`.

**Load factor:** `load_factor()` reports the fraction of slots currently
holding a fingerprint, in `[0, 1]`.

**Set operations:**
- `union`: copies fingerprints, returns `None` if combined entries don't fit
- `intersection`: processes unordered candidate pairs, keeps smaller
  multiplicity; never drops a key both inputs report
- `is_subset_of`: compares fingerprints across both candidate buckets

## Concurrent Wrappers

`Concurrent*` wrappers serialize every operation with a mutex.

```moonbit
let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
filter.insert("shared")
assert_true(filter.contains("shared"))

let keys = ["a", "b", "c"]
filter.insert_all(keys)
assert_true(filter.contains_all(keys))

// Atomic snapshot for consistent reads
let snapshot = filter.snapshot()
filter.insert("after-snapshot")
assert_false(snapshot.contains("after-snapshot"))
```

**Target behavior:**
- Native/LLVM: real OS mutex via C stub
- JS/Wasm/Wasm-GC: no-op mutex (single-threaded runtime)
- Wrappers do **not** make filters safe to share across workers/threads on
  Wasm/JS targets

**Available wrappers:**
- `ConcurrentBloomFilter`
- `ConcurrentBlockedBloomFilter`
- `ConcurrentCountingBloomFilter`
- `ConcurrentCompactCountingBloomFilter`
- `ConcurrentCuckooFilter`
- `ConcurrentScalableBloomFilter`
- `ConcurrentScalableCountingBloomFilter`

All expose `copy()` (lock held during copy) and `snapshot()` (alias for
`copy()`). Batch operations take the lock once.

## Set Operations

Filters with identical configuration can be combined without re-hashing:

```moonbit
let left = @src.BloomFilter::with_size(4096, 4)
let right = @src.BloomFilter::with_size(4096, 4)
left.insert("left")
right.insert("right")

let union = left.union(right)
assert_true(union.contains("left"))
assert_true(union.contains("right"))
assert_true(left.is_subset_of(union))
```

| Operation | Description | Returns |
| --- | --- | --- |
| `merge(other)` | In-place union | `Unit` |
| `union(other)` | New filter with union | New filter or `None` if full |
| `intersection(other)` | New filter with intersection | New filter |
| `is_subset_of(other)` | Every bit/counter in self ≤ other | `Bool` |
| `is_disjoint_from(other)` | No shared bits/counters/fingerprints | `Bool` |

**Shortcuts:**
- Empty operands return immediately without scanning
- Counting variants use exact counter mass for O(1) emptiness checks
- Scalable variants skip zero-insertion slices
- Merging into empty receiver copies storage directly

**Concurrent wrappers:** Take the other filter as unwrapped plain filter;
receiver is locked, other is not—don't mutate other from another thread during
the operation.

## Serialization

Every filter supports versioned binary serialization:

```moonbit
let original = @src.ScalableBloomFilter::new(1_000, 0.01)
original.insert("saved")
let restored = @src.ScalableBloomFilter::from_bytes(original.to_bytes())
assert_true(restored.contains("saved"))
```

**Format:** Configuration, insertion count, backing array + type tag + version.
**Restoration:** `from_bytes` panics on truncated data, wrong type, unknown
version, or invalid config.
**Hashing:** Fixed seeds ensure consistent positions across processes.
**Cuckoo:** Eviction state preserved; zero state rejected (would break
placement).

## Sizing Before Allocation

`optimal_size` helpers compute layouts without allocating:

```moonbit
let (bits, hashes) = @src.BloomFilter::optimal_size(10_000, 0.01)
let filter = @src.BloomFilter::new(10_000, 0.01)
assert_eq(bits, filter.bit_count())
assert_eq(hashes, filter.hash_count())
assert_eq(bits.to_int64() / 8L, filter.memory_bytes())
```

| Filter | Returns |
| --- | --- |
| `BloomFilter` / `BlockedBloomFilter` | `(bit_count, hash_count)` |
| `CountingBloomFilter` / `CompactCountingBloomFilter` | `(slot_count, hash_count)` (slots rounded to multiple of 16) |
| `CuckooFilter` | `(bucket_count, bucket_size)` (power of two) |
| `ScalableBloomFilter` / `ScalableCountingBloomFilter` | First slice layout only |

Concurrent wrappers expose the same helpers without taking the mutex.

## Performance Characteristics

Let `k = hash_count()`, `m = bits/slots`, `s = slices`, `B = bucket_size`.

| Filter | Insert/Query | Memory | Notes |
| --- | --- | --- | --- |
| `BloomFilter` / `BlockedBloomFilter` | O(k) | m/8 bytes | Blocked: 1 cache line/query |
| `CountingBloomFilter` | O(k) | 2m bytes | Workspace: min(k, m) |
| `CompactCountingBloomFilter` | O(k) | m/2 bytes | Same workspace |
| `CuckooFilter` | O(B) expected | m bytes | BFS on eviction failure |
| `Scalable*` | O(s·k) | Grows | Empty slices skipped |

**Optimizations:**
- Empty filters: O(1) queries without hashing
- Full filters: word scan replaces wide probe walks
- Power-of-two layouts: cycle detection avoids GCD per query
- Counting filters: exact counter mass for O(1) emptiness
- Concurrent: batch ops take lock once

## Configuration and Errors

Constructors panic on invalid arguments:

- `expected_items`, `bit_count`, `slot_count`, `bucket_count` must be positive
- `false_positive_rate` must satisfy `0 < rate < 1`
- `hash_count`, `bucket_size` must be positive
- Overflowing requests panic instead of silently wrapping
- `from_bytes` panics on truncated data, wrong type tag, unknown version,
  or configuration that cannot produce the claimed size

**Sizing formula:** For rate `p` and `n` items, Bloom filters need roughly
`-n * ln(p) / (ln 2)^2` bits and `-log2(p)` hash functions. Larger `n` than
actual workload lowers false-positive rate; smaller raises it.

**Capacity overflow:** When inserting would exceed the maximum supported size,
the constructor panics. This can happen during slice growth in scalable filters
or when merging filters with combined sizes beyond the limit.

## Testing and Benchmarks

```bash
moon check
moon test                 # Default target
moon test --target native # Native mutex + C stub
moon test --target all    # All backends
moon bench --release      # Benchmarks in src/benchmark_test.mbt
```

Benchmarks cover insertion, queries, batch ops, conditional insertion,
multiplicity queries, deletion, set operations, serialization, compact counting,
and concurrent wrappers.