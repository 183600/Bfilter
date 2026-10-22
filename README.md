# Bfilter — probabilistic filters for MoonBit

`Bfilter` is a MoonBit library of Bloom-filter-family data structures. It
implements classic Bloom filters, counting variants, scalable filters, Cuckoo
filters, serialization, set operations, and mutex-protected concurrent
wrappers.

- Module: `183600/bfilter`
- Repository: <https://github.com/183600/Bfilter>
- License: MIT

The repository is named `Bfilter`; the MoonBit module is lowercase
(`183600/bfilter`) to follow package naming conventions.

## Implemented filters

| Type | Deletion | Notes |
| --- | --- | --- |
| `BloomFilter` | no | Bit-packed, standard Bloom filter with configurable false-positive rate. |
| `BlockedBloomFilter` | no | Cache-friendly blocked layout: every probe of a key lands in one memory block. |
| `CountingBloomFilter` | yes | 16-bit saturating counters; `remove` and `count_of` are supported. |
| `CompactCountingBloomFilter` | yes | 4-bit packed counters, about a quarter of the memory of the counting filter. |
| `ScalableBloomFilter` | no | Grows by adding slices; `merge` combines compatible filters. |
| `ScalableCountingBloomFilter` | yes | Scalable slices built on counting filters. |
| `CuckooFilter` | yes | Fingerprint buckets with eviction; different false-positive and capacity model from Bloom filters. |
| `Concurrent*` wrappers | as wrapped | Native/LLVM use an OS mutex; JS/Wasm targets use a no-op lock because a module runs on one thread. |

All filters accept any key type with a `Hash` implementation and expose
`insert`, `contains`, batch helpers, statistics, and versioned
`to_bytes`/`from_bytes` serialization. The fixed-size constructors also expose
`optimal_size(...)`, which computes the same layout as `new` without allocating
the backing array; the concurrent wrappers forward the same helper for their
fixed-size layouts. The full API, set-operation semantics, and complexity and
memory bounds are documented in [docs/guide.md](docs/guide.md).

## Quick start

The module is not yet published to the mooncakes registry, so `moon add
183600/bfilter` does not work at the moment. Until it is published, consume
the module from a git checkout through a MoonBit workspace.

Declare the dependency in your application's `moon.mod` (version must match
the module's `moon.mod`):

```toml
import {
  "183600/bfilter@0.2.0",
}
```

Clone the repository next to your project and register both modules as
workspace members:

```bash
git clone https://github.com/183600/Bfilter.git
moon work init                # creates moon.work, skip if it exists
moon work use ./Bfilter
moon work use ./path/to/your-app
```

Then import the `src` package and use the filters:

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

Counting and Cuckoo filters support deletion:

```moonbit
///|
test "deletion-capable variants" {
  let counting = @src.CountingBloomFilter::new(1_000, 0.01)
  counting.insert("session")
  assert_true(counting.remove("session"))

  let cuckoo = @src.CuckooFilter::new(1_000)
  assert_true(cuckoo.insert("session"))
  assert_true(cuckoo.remove("session"))
  assert_false(cuckoo.contains("session"))
}
```

## Set operations

Filters with the same configuration can be combined without re-hashing keys:

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

`merge` performs the union in place. `intersection`, `is_disjoint_from`, and
`is_subset_of` are available on the Bloom family; the Cuckoo filter has its own
set-operation semantics documented in the guide. Mismatched configurations
panic rather than silently producing a wrong result.

## Concurrency

`ConcurrentBloomFilter`, `ConcurrentCountingBloomFilter`,
`ConcurrentCuckooFilter`, and the other `Concurrent*` wrappers serialize each
operation with a mutex. Batch operations take the lock once, and `snapshot()`
returns an independent copy while holding the lock.

The mutex is a real OS mutex on native/LLVM targets. On JavaScript and Wasm it
is a no-op because those runtimes execute a module on a single thread; the
wrappers do not make a filter safe to share across workers/threads on those
targets.

## Serialization

Every filter supports a versioned binary format:

```moonbit
let original = @src.ScalableBloomFilter::new(1_000, 0.01)
original.insert("saved")
let restored = @src.ScalableBloomFilter::from_bytes(original.to_bytes())
assert_true(restored.contains("saved"))
```

`from_bytes` panics on truncated input, a different filter type, an unknown
version, or an invalid configuration. Hashing uses fixed seeds, so persisted
filters behave the same in a new process.

## Project layout

```text
.
├── moon.mod                 # module metadata
├── scripts/                 # hygiene check used by CI
├── src/
│   ├── moon.pkg             # package config, native C stub, test imports
│   ├── pkg.generated.mbti   # generated public interface (moon info)
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
moon test                 # default target
moon test --target native # exercise the native mutex + C stub
moon test --target all    # every supported backend
moon bench --release      # benchmarks in src/benchmark_test.mbt
```

CI (`.github/workflows/ci.yml`) runs `moon check`, the default test suite, the
native test suite, and a repository-hygiene check on every push and pull
request.

## Contributing

Keep new tests deterministic and name them after the behavior under test. Do
not commit scratch/probe files (`zz_*`, `tmp_*`, `_scratch_*`, `dbg_*`); put
throwaway scripts in `/tmp`. Add a regression test for every bug fix and update
`docs/guide.md` when public behavior changes.

## License

MIT — see [LICENSE](LICENSE).
