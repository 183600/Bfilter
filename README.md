# Bfilter — Probabilistic Filters for MoonBit

`Bfilter` is a MoonBit library of Bloom-filter-family data structures. It
provides classic Bloom filters, counting variants, scalable filters, Cuckoo
filters, serialization, set operations, and mutex-protected concurrent
wrappers.

- Module: `183600/bfilter`
- Repository: <https://github.com/183600/Bfilter>
- License: MIT

The repository is named `Bfilter`; the MoonBit module is lowercase
(`183600/bfilter`) to follow package naming conventions.

## Contents

- [Filter Catalogue](#filter-catalogue)
- [Installation](#installation)
- [Usage](#usage)
  - [Bloom Filter](#bloom-filter)
  - [Counting Bloom Filter](#counting-bloom-filter)
  - [Compact Counting Bloom Filter](#compact-counting-bloom-filter)
  - [Blocked Bloom Filter](#blocked-bloom-filter)
  - [Scalable Filters](#scalable-filters)
  - [Cuckoo Filter](#cuckoo-filter)
  - [Concurrent Filters](#concurrent-filters)
- [Set Operations](#set-operations)
- [Serialization](#serialization)
- [Choosing a Filter](#choosing-a-filter)
- [Project Layout](#project-layout)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Filter Catalogue

| Type | Deletion | Counter Width | Memory | Use Case |
| --- | --- | --- | --- | --- |
| `BloomFilter` | no | 1 bit | ~1.25 bytes/item | General-purpose, lowest memory |
| `BlockedBloomFilter` | no | 1 bit | ~1.25 bytes/item | Cache-friendly, high-throughput queries |
| `CountingBloomFilter` | yes | 16-bit | ~8 bytes/item | Deletion and multiplicity tracking |
| `CompactCountingBloomFilter` | yes | 4-bit | ~2 bytes/item | Memory-constrained deletion, low multiplicity |
| `ScalableBloomFilter` | no | 1 bit | Grows dynamically | Unbounded insertions, known false-positive budget |
| `ScalableCountingBloomFilter` | yes | 16-bit | Grows dynamically | Unbounded insertions with deletion |
| `CuckooFilter` | yes | 8-bit fingerprint | ~1 byte/item | High load factor, exact deletion |
| `Concurrent*` wrappers | as wrapped | — | Same as wrapped | Thread-safe access on native/LLVM |

All filters accept any key type with a `Hash` implementation and expose
`insert`, `contains`, batch helpers, statistics, and versioned
`to_bytes`/`from_bytes` serialization.

The fixed-size constructors also expose `optimal_size(...)`, which computes the
same layout as `new` without allocating the backing array; the concurrent
wrappers forward the same helper for their fixed-size layouts. The scalable
filters expose `optimal_size(...)` for the first slice they create, which is
useful for planning the initial allocation before growth begins.

The full API, set-operation semantics, and complexity and memory bounds are
documented in [docs/guide.md](docs/guide.md).

## Installation

The module is not yet published to the Mooncakes registry, so `moon add
183600/bfilter` is unavailable. Until it is published, consume the module from
a local git checkout via a MoonBit workspace.

Declare the dependency in your application's `moon.mod`. The version must match
the library's `moon.mod`:

```toml
import {
  "183600/bfilter@0.2.0",
}
```

Place the repository alongside your project so both checkouts share a parent
directory. From that parent directory, register both modules as workspace
members:

```bash
git clone https://github.com/183600/Bfilter.git
moon work init                # creates moon.work, skip if it exists
moon work use ./Bfilter
moon work use ./path/to/your-app
```

An example is provided in `examples/`. It is a separate module linked through the
repository's `moon.work`, so you can build and run it from the repository root:

```bash
moon run examples
```

The example shows filter creation, batch insertion, queries, false-positive rate
observation, and a `to_bytes`/`from_bytes` round trip.

In the package that uses the filters, add the `src` package to its `moon.pkg`
import block with the `@src` alias:

```toml
import {
  "183600/bfilter/src" @src,
}
```

## Usage

### Bloom Filter

`BloomFilter::new(expected_items, false_positive_rate)` derives the bit count
and hash count from the standard Bloom filter formulas.

```moonbit
///|
test "bloom filter quick start" {
  let filter = @src.BloomFilter::new(10_000, 0.01)
  filter.insert("alpha")
  filter.insert_all(["beta", "gamma"])

  assert_true(filter.contains("alpha"))
  assert_true(filter.contains_all(["beta", "gamma"]))
  assert_false(filter.contains("not-inserted"))

  // A Bloom filter can produce false positives, never false negatives for
  // keys that were inserted successfully.
  assert_true(filter.false_positive_rate() < 0.02)
}
```

### Counting Bloom Filter

`CountingBloomFilter` stores a 16-bit counter per slot, so keys can be removed
and their multiplicity can be queried.

```moonbit
///|
test "counting bloom filter with deletion" {
  let filter = @src.CountingBloomFilter::new(1_000, 0.01)
  filter.insert("session")
  filter.insert("session")  // Duplicate insertions increment multiplicity

  assert_eq(filter.count_of("session"), 2)
  assert_true(filter.remove("session"))
  assert_eq(filter.count_of("session"), 1)
  assert_true(filter.remove("session"))
  assert_false(filter.contains("session"))
}
```

### Compact Counting Bloom Filter

`CompactCountingBloomFilter` packs each counter into a 4-bit nibble and uses
roughly a quarter of the memory of `CountingBloomFilter`. Counters saturate at
15, so keep multiplicities low.

```moonbit
///|
test "compact counting bloom filter" {
  let compact = @src.CompactCountingBloomFilter::new(1_000, 0.01)
  let regular = @src.CountingBloomFilter::new(1_000, 0.01)

  // Compact version uses ~1/4 the memory
  assert_eq(regular.memory_bytes(), compact.memory_bytes() * 4L)

  compact.insert("task")
  compact.insert("task")
  assert_eq(compact.count_of("task"), 2)
  assert_true(compact.remove("task"))
  assert_eq(compact.count_of("task"), 1)
}
```

### Blocked Bloom Filter

`BlockedBloomFilter` keeps every probe for a key inside one 512-bit block, so a
query touches a single cache line instead of scattering accesses across the
whole bit array.

```moonbit
///|
test "blocked bloom filter block layout" {
  let filter = @src.BlockedBloomFilter::new(10_000, 0.01)
  filter.insert_all(["alpha", "beta"])

  assert_true(filter.contains("alpha"))
  assert_true(filter.contains_all(["alpha", "beta"]))
  assert_eq(filter.bit_count() % 512, 0)
  assert_eq(filter.block_count(), filter.bit_count() / 512)
}
```

### Scalable Filters

`ScalableBloomFilter` and `ScalableCountingBloomFilter` start with one slice and
append slices when the newest one reaches its planned capacity. Each new slice
doubles the capacity and halves its share of the false-positive budget.

```moonbit
///|
test "scalable bloom filter grows automatically" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.slice_count() > 1)
  assert_true(filter.contains(42))
  assert_eq(filter.count(), 1000)
}
```

```moonbit
///|
test "scalable counting bloom filter tracks multiplicity" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert("session")
  filter.insert("session")

  assert_eq(filter.count_of("session"), 2)
  assert_true(filter.remove("session"))
  assert_eq(filter.count_of("session"), 1)
}
```

### Cuckoo Filter

`CuckooFilter` stores one-byte fingerprints in two candidate buckets per key.
Insertion may evict existing entries; a failed insertion restores every
eviction.

```moonbit
///|
test "cuckoo filter insertion and deletion" {
  let filter = @src.CuckooFilter::new(1_000)
  assert_true(filter.insert("session-1"))
  assert_true(filter.contains("session-1"))
  assert_true(filter.remove("session-1"))
  assert_false(filter.contains("session-1"))
}
```

### Concurrent Filters

Every filter has a `Concurrent*` wrapper that serializes each operation with a
mutex. Batch operations take the lock once, and `copy()` / `snapshot()` return
an independent copy while holding the lock.

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

## Set Operations

Filters with the same configuration can be combined without re-hashing keys:

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

- `merge` performs the union in place
- `intersection`, `is_disjoint_from`, and `is_subset_of` are available on the Bloom family
- The Cuckoo filter has its own set-operation semantics documented in the guide
- Mismatched configurations panic rather than silently producing a wrong result
- Empty operands short-circuit without scanning the backing array
- Merging a non-empty filter into an empty receiver copies storage directly

## Serialization

Every filter supports a versioned binary format:

```moonbit
///|
test "serialization round trip" {
  let original = @src.ScalableBloomFilter::new(1_000, 0.01)
  original.insert("saved")
  let restored = @src.ScalableBloomFilter::from_bytes(original.to_bytes())
  assert_true(restored.contains("saved"))
}
```

`from_bytes` panics on truncated input, a different filter type, an unknown
version, or an invalid configuration. Hashing uses fixed seeds, so persisted
filters behave the same in a new process.

## Choosing a Filter

| Requirement | Recommended Filter |
| --- | --- |
| Minimum memory, no deletion | `BloomFilter` |
| High query throughput, cache-friendly | `BlockedBloomFilter` |
| Need deletion & multiplicity | `CountingBloomFilter` |
| Deletion with memory constraints | `CompactCountingBloomFilter` |
| Unbounded insertions, no deletion | `ScalableBloomFilter` |
| Unbounded insertions with deletion | `ScalableCountingBloomFilter` |
| High load factor, exact deletion | `CuckooFilter` |
| Thread-safe access (native) | `Concurrent*` wrapper |

## Project Layout

```text
.
├── moon.mod                 # Module metadata
├── moon.work                # Workspace linking the library and examples
├── examples/                # Runnable example module
│   ├── moon.mod
│   ├── moon.pkg
│   └── main.mbt
├── scripts/                 # Hygiene check used by CI
├── src/
│   ├── moon.pkg             # Package config, native C stub, test imports
│   ├── pkg.generated.mbti   # Generated public interface (moon info)
│   ├── layout.mbt           # Shared sizing and validation helpers
│   ├── bloom_filter.mbt
│   ├── blocked_bloom_filter.mbt
│   ├── counting_bloom_filter.mbt
│   ├── compact_counting_bloom_filter.mbt
│   ├── scalable_*.mbt
│   ├── cuckoo_filter.mbt
│   ├── concurrent_*.mbt
│   ├── serialization.mbt
│   ├── mutex_native.mbt / mutex_single_threaded.mbt
│   └── *_test.mbt
└── docs/guide.md            # API and design guide
```

## Development

Requires a recent MoonBit toolchain (the CI installs the latest stable from
`cli.moonbitlang.com`).

```bash
moon check
moon test                 # Default target
moon test --target native # Exercise the native mutex + C stub
moon test --target all    # Every supported backend
moon bench --release      # Benchmarks in src/benchmark_test.mbt
```

CI (`.github/workflows/ci.yml`) runs on pushes to `main`, on pull requests, and
on manual dispatch. It resolves dependencies with `moon update`, then runs
`moon check --target all`, the default and native test suites, and a
repository-hygiene check.

## Contributing

Keep new tests deterministic and name them after the behavior under test. Do
not commit scratch/probe files (`zz_*`, `tmp_*`, `_scratch_*`, `dbg_*`); put
throwaway scripts in `/tmp`. Add a regression test for every bug fix and update
`docs/guide.md` when public behavior changes.

## License

MIT — see [LICENSE](LICENSE).
