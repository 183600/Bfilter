# Bfilter User Guide

Bfilter provides probabilistic set data structures for MoonBit. Every filter
accepts any key type that implements `Hash`, such as `String`, integers, or
user-defined types with a `Hash` implementation.

This guide walks through the shared API, describes each filter type, and
documents the guarantees and caveats that matter when you pick one.

## Contents

- [Quick Start](#quick-start)
- [Choosing a Filter](#choosing-a-filter)
- [Core Concepts](#core-concepts)
  - [False Positives and False Negatives](#false-positives-and-false-negatives)
  - [Hashing](#hashing)
  - [Shared API](#shared-api)
  - [Batch Operations](#batch-operations)
  - [Statistics](#statistics)
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
///|
test "quick start" {
  let filter = @src.BloomFilter::new(1_000, 0.01)
  filter.insert("alpha")
  filter.insert("beta")

  assert_true(filter.contains("alpha"))
  assert_false(filter.contains("gamma"))
}
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

Two questions settle most choices:

1. **Do you need to remove keys?** Only the counting filters, the scalable
   counting filter, and the Cuckoo filter support deletion.
2. **Do you know how many keys to expect?** The scalable filters keep
   accepting insertions by adding slices; the fixed-size filters do not grow.

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
- Two filters that use the same layout derive the same positions for the same
  key, which is what makes set operations possible without re-hashing.

### Shared API

Every filter exposes the same core operations. The table lists the method and
the filters that provide it.

| Operation | Provided by | Result |
| --- | --- | --- |
| `insert(key)` | all filters | Adds the key; counting filters raise its multiplicity |
| `insert_if_absent(key)` | all filters | `true` when the key was added |
| `contains(key)` | all filters | `true` when the key may be present |
| `insert_all(keys)` | all filters | Adds every key (`Bool` for the Cuckoo filter) |
| `insert_all_if_absent(keys)` | all filters | Number of keys added |
| `contains_all(keys)` | all filters | `true` when every key may be present |
| `contains_any(keys)` | all filters | `true` when at least one key may be present |
| `remove(key)` | counting, scalable counting, Cuckoo | `true` when one occurrence was removed |
| `remove_all(keys)` | counting, scalable counting, Cuckoo | `true` when every key was removed |
| `count_of(key)` | counting, scalable counting, Cuckoo | Multiplicity of one key |
| `count()` | all filters | Number of insertions since the last `clear` |
| `is_empty()` | all filters | `true` when nothing has been inserted |
| `clear()` | all filters | Removes every key and resets the counters |
| `copy()` | all filters | Independent copy of the filter |
| `merge(other)` | all filters | In-place union (`Bool` for the Cuckoo filter) |
| `union(other)` | all filters | New filter holding the union (`None` if it does not fit) |
| `intersection(other)` | all filters | New filter holding the intersection |
| `is_subset_of(other)` | all filters | `true` when `self` is covered by `other` |
| `is_disjoint_from(other)` | all filters | `true` when the filters provably share no key |
| `memory_bytes()` | all filters | Bytes used by the backing storage |
| `false_positive_rate()` | all filters | Estimated false-positive rate |
| `to_bytes()` / `from_bytes(data)` | all filters | Versioned binary round trip |

`count()` counts insertion calls, not distinct keys: inserting the same key
twice increments it twice. Use `count_of(key)` when you need the multiplicity
of a single key.

### Batch Operations

Every filter exposes batch helpers for efficiency:

- `insert_all(keys)` — inserts all keys
- `insert_all_if_absent(keys)` — inserts only absent keys, returns count added
- `contains_all(keys)` — returns `true` only if all keys are present
- `contains_any(keys)` — returns `true` if at least one key is present
- `remove_all(keys)` — removes all keys (counting and Cuckoo filters only)

Empty batches are no-ops and never touch the backing storage. Batch helpers
continue after a failure instead of aborting the batch; `remove_all` and the
Cuckoo filter's `insert_all` report the overall result as a `Bool`.

### Statistics

| Method | Provided by | Meaning |
| --- | --- | --- |
| `count()` | all filters | Insertion calls since creation or the last `clear` |
| `is_empty()` | all filters | Whether nothing has been inserted |
| `is_full()` | fixed-size filters | Whether every bit or counter slot is occupied |
| `set_bit_count()` | Bloom family | Number of bits currently set |
| `occupied_slot_count()` | counting family | Number of counter slots currently positive |
| `fill_ratio()` | Bloom and counting families | Fraction of the storage that is occupied |
| `estimated_item_count()` | Bloom and counting families | Estimated number of distinct keys represented |
| `load_factor()` | Cuckoo filter | Fraction of slots that hold a fingerprint |
| `memory_bytes()` | all filters | Bytes used by the backing storage |
| `false_positive_rate()` | all filters | Estimated false-positive rate for the current state |

The Bloom family uses bit counts, the counting family uses occupied slots, and
the Cuckoo filter uses `load_factor()` for the fraction of slots that hold a
fingerprint. The scalable filters have no fixed size, so they report
`slice_count()` and `capacity()` instead of `is_full()`.

## Filter Types

### Bloom Filter

`BloomFilter::new(expected_items, false_positive_rate)` sizes the filter from
the standard Bloom filter formulas. `BloomFilter::with_size(bit_count,
hash_count)` is available when a configuration is already known.

```moonbit
///|
test "bloom filter" {
  let filter = @src.BloomFilter::new(10_000, 0.001)
  for i = 0; i < 10_000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.contains(123))
  assert_true(filter.false_positive_rate() < 0.01)
}
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
///|
test "blocked bloom filter" {
  let filter = @src.BlockedBloomFilter::new(10_000, 0.001)
  filter.insert_all(["alpha", "beta"])
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains_all(["alpha", "beta"]))
  assert_eq(filter.bit_count() % 512, 0)
  assert_eq(filter.block_count(), filter.bit_count() / 512)
}
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
///|
test "counting bloom filter" {
  let filter = @src.CountingBloomFilter::new(1_000, 0.01)
  filter.insert("task")
  filter.insert("task")
  assert_eq(filter.count(), 2)

  assert_true(filter.remove("task"))
  assert_true(filter.contains("task"))
  assert_true(filter.remove("task"))
  assert_false(filter.contains("task"))
}
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
///|
test "compact counting bloom filter" {
  let compact = @src.CompactCountingBloomFilter::new(1_000, 0.01)
  let regular = @src.CountingBloomFilter::new(1_000, 0.01)
  assert_eq(regular.memory_bytes(), compact.memory_bytes() * 4L)

  compact.insert("task")
  compact.insert("task")
  assert_eq(compact.count_of("task"), 2)
  assert_true(compact.remove("task"))
  assert_eq(compact.count_of("task"), 1)
}
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
///|
test "scalable bloom filter" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 1000)
  assert_true(filter.target_false_positive_rate() == 0.01)
  assert_true(filter.false_positive_rate() < 0.01)
}
```

**Key properties:**
- Keys stay in the slice where they were first inserted
- `insert_if_absent` checks all slices before inserting
- `clear` reuses the first slice's backing array and drops later slices
- Set operations (`merge`, `union`, `intersection`, `is_subset_of`,
  `is_disjoint_from`) combine slices by index

**Set operation caveats:**
- `intersection` only compares slices at matching indices, so it can omit a key
  both inputs contain if they placed it in different slices. Most useful when
  inputs grew in lockstep.
- `is_disjoint_from` compares slices at different indices with different hash
  layouts; it returns `true` (provably disjoint) only when no pair of non-empty
  slices can share a key, which requires both the layout and bit overlap to
  match. This is a strict check that may return `false` even when no shared key
  exists, simply because different slice indices use different hash layouts.

```moonbit
///|
test "scalable bloom intersection caveat: same key in different slices" {
  let left = @src.ScalableBloomFilter::new(4, 0.000001)
  let right = @src.ScalableBloomFilter::new(4, 0.000001)
  left.insert("shared")
  for i = 0; i < 8; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 30; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  right.insert("shared")
  assert_true(left.slice_count() > 1)
  assert_true(right.slice_count() > left.slice_count())
  let common = left.intersection(right)
  // The "shared" key is in slice 0 of left but a later slice of right.
  // Slice-by-slice intersection misses it.
  assert_false(common.contains("shared"))
  assert_true(left.contains("shared"))
  assert_true(right.contains("shared"))
}
```

### Scalable Counting Bloom Filter

`ScalableCountingBloomFilter` combines slice growth with removable counters.
Each key is tracked with its exact multiplicity and owning slice.

```moonbit
///|
test "scalable counting bloom filter" {
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
}
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
///|
test "cuckoo filter" {
  let filter = @src.CuckooFilter::new(10_000)
  assert_true(filter.insert("session-1"))
  assert_true(filter.contains("session-1"))
  assert_true(filter.remove("session-1"))
  assert_false(filter.contains("session-1"))
}
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
path exists, so a non-zero `remaining_capacity()` does not guarantee the next
`insert` succeeds. `is_full()` checks whether `inserted >= capacity`.

`insert_all` continues after an insertion failure and returns `true` only
when every key was inserted. When the filter fills mid-batch, some keys may
be inserted while later ones are rejected; the filter's state is still
consistent and no previously stored fingerprint is lost.

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
///|
test "concurrent bloom filter" {
  let filter = @src.ConcurrentBloomFilter::new(1_000, 0.01)
  filter.insert("shared")
  assert_true(filter.contains("shared"))

  let keys = ["a", "b", "c"]
  filter.insert_all(keys)
  assert_true(filter.contains_all(keys))

  // Atomic snapshot for consistent reads
  let snapshot = filter.snapshot()
  filter.insert("after-snapshot")
  assert_false(snapshot.contains("after-snapshot"))
}
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
///|
test "bloom filter set operations" {
  let left = @src.BloomFilter::with_size(4096, 4)
  let right = @src.BloomFilter::with_size(4096, 4)
  left.insert("left")
  right.insert("right")

  let union = left.union(right)
  assert_true(union.contains("left"))
  assert_true(union.contains("right"))
  assert_true(left.is_subset_of(union))
}
```

| Operation | Description | Returns |
| --- | --- | --- |
| `merge(other)` | In-place union | `Unit` (Cuckoo: `Bool`) |
| `union(other)` | New filter with union | New filter (`None` for the Cuckoo filter when the entries do not fit) |
| `intersection(other)` | New filter with intersection | New filter |
| `is_subset_of(other)` | Every element reported by self is also reported by other | `Bool` |
| `is_disjoint_from(other)` | No shared bits/counters/fingerprints | `Bool` |

**Compatibility:** The two operands must share the same layout. A mismatch
panics instead of silently producing a wrong result.

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
///|
test "serialization round trip" {
  let original = @src.ScalableBloomFilter::new(1_000, 0.01)
  original.insert("saved")
  let restored = @src.ScalableBloomFilter::from_bytes(original.to_bytes())
  assert_true(restored.contains("saved"))
}
```

**Format:** Configuration, insertion count, backing array + type tag + version.
**Restoration:** `from_bytes` panics on empty data, truncated data, wrong
type, unknown version, or invalid config.
**Hashing:** Fixed seeds ensure consistent positions across processes.
**Cuckoo:** Eviction state preserved; zero state rejected (would break
placement).

The concurrent wrappers expose the same `to_bytes` / `from_bytes` pair and hold
the lock while encoding.

## Sizing Before Allocation

`optimal_size` helpers compute layouts without allocating:

```moonbit
///|
test "sizing before allocation" {
  let (bits, hashes) = @src.BloomFilter::optimal_size(10_000, 0.01)
  let filter = @src.BloomFilter::new(10_000, 0.01)
  assert_eq(bits, filter.bit_count())
  assert_eq(hashes, filter.hash_count())
  assert_eq(bits.to_int64() / 8L, filter.memory_bytes())
}
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
