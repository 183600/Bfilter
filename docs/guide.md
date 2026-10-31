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

Storage is bit-packed: because `bit_count()` is always a multiple of 64, the
backing array uses exactly `bit_count / 8` bytes. `bit_count()` reports the
rounded-up number of addressable bits, and
`false_positive_rate()` estimates the current rate from the insertion count.
When `bit_count()` is a power of two, a very wide `hash_count` stops after one
double-hash cycle: every later probe repeats a bit that an earlier probe already
set or tested. This keeps an otherwise valid but unusually wide configuration
from scanning the full nominal hash count. Other bit counts are not purely
periodic, so they still perform every configured probe. Independently of the
cycle, a completely full filter cannot change, so an effective probe walk that
is wider than the backing word array is replaced by one scan of those words:
queries return `true` and conditional insertions return `false` without probing.
This covers wide non-power-of-two layouts and power-of-two layouts whose
double-hash period is long. A filter with no insertions has no set bits, so
queries also return `false` without probing. Prefer a power-of-two bit count when
planning an unusually wide `hash_count`.

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

Empty operands are handled without scanning the backing arrays: `intersection`
returns an empty filter with the shared layout, `is_subset_of` is immediately
true when `self` is empty, and `is_disjoint_from` is immediately true when
either input is empty. The same shortcuts apply to the blocked, counting, and
compact counting variants. The counting variants also maintain an exact total
counter mass, so `merge`, `intersection`, `is_subset_of`,
`is_disjoint_from`, and `clear` can short-circuit an operand with no positive
counter without scanning its packed counter words. The scalable variants keep
the shortcut as well:
their `is_subset_of` and `is_disjoint_from` checks return without scanning the
slice storage when the relevant insertion count is zero. While checking a
non-empty scalable filter, a slice whose own insertion count is zero is also
skipped without scanning its bits or counters. The scalable counting variant
uses each slice's exact counter mass for the same positivity check, and merging
a count-only source no longer scans that source's counter arrays. Merging a
non-empty filter into an empty receiver copies its bits or counters instead of
combining them with zeroed storage.

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

On the concurrent wrappers these set operations take the *other* filter as an
unwrapped plain filter (for example
`ConcurrentBloomFilter::merge(other : BloomFilter)`): the receiver is locked,
but `other` is not, so do not mutate it from another thread while the
operation runs.

`is_disjoint_from(other)` answers the opposite question: it returns `true` only
when the filters are definitely disjoint, meaning no key can be reported present
by both. For Bloom filters that requires no shared set bit, for counting
variants no slot with a positive counter in both, and for cuckoo filters no
fingerprint that appears in the matching candidate pair of the other filter. A
`false` result is inconclusive because shared bits or fingerprints may come from
different keys. Every base filter type and its concurrent wrapper exposes the
method, and it panics when the layouts differ.

## Blocked Bloom Filter

`BlockedBloomFilter` keeps every probe for a key inside one 512-bit block, so a
query touches at most one cache line instead of scattering accesses across the
whole bit array. It exposes the same construction, batch, set-algebra, and
serialization API as `BloomFilter`, and `ConcurrentBlockedBloomFilter` adds the
same mutex protection as the other concurrent wrappers.

```moonbit
let filter = @src.BlockedBloomFilter::new(10_000, 0.001)
filter.insert_all(["alpha", "beta"])
assert_true(filter.contains("alpha"))
assert_true(filter.contains_all(["alpha", "beta"]))
assert_eq(filter.bit_count() % 512, 0)
assert_eq(filter.block_count(), filter.bit_count() / 512)
```

`with_size(bit_count, hash_count)` rounds the bit count up to whole blocks, so
`bit_count()` is always a multiple of 512. Block selection is derived from the
key hash and the remaining probes use double hashing within that block. The
odd probe step and the 512-bit block size mean the offset sequence repeats after
at most 512 probes, so a wider `hash_count` is capped at one cycle. Blocks fill
unevenly, which can raise the observed false-positive rate slightly above a
classic Bloom filter with the same total bit count, but the standard
`fill_ratio()`, `estimated_item_count()`, and `false_positive_rate()` estimates
remain available. A completely full filter is detected with one scan of the
backing words when its capped probe walk is wider than that array; queries then
return `true` and conditional insertions return `false` without walking the
block cycle. Filters can be combined when their rounded bit counts and hash
counts match, exactly like `BloomFilter`.

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
empty slice with the original initial capacity. It reuses the first slice's
backing array and drops any later slices instead of allocating a new slice.
`ConcurrentScalableBloomFilter`
provides the same operations with one mutex and a `snapshot()` method.

Scalable bloom filters can also be combined when they share the same initial
capacity and target false-positive rate. Slices are matched by index, so
`ScalableBloomFilter::merge` ORs the bits of corresponding slices and appends
slices that only the other filter holds. `union` returns a new combined filter,
`intersection` intersects slices with the same index up to the shorter input,
and `is_subset_of` compares each slice against the slice with the same index:

```moonbit
let left = @src.ScalableBloomFilter::new(100, 0.01)
let right = @src.ScalableBloomFilter::new(100, 0.01)
for i = 0; i < 250; i = i + 1 {
  left.insert(i)
  right.insert(i + 1000)
}
let combined = left.union(right)
assert_true(combined.contains(42))
assert_true(combined.contains(1042))
assert_true(left.is_subset_of(combined))
```

Keys stay in the slice where they were first inserted, so filters with different
insert histories can store the same key in different slices. The scalable bloom
filter's `intersection` only compares slices at matching indices, so it can omit
a key that both inputs contain when they placed it in different slices; it is
most useful when the inputs grew in lockstep. `merge` and `union` preserve every
slice, and its `is_subset_of` is conservative for the same reason: it may return
`false` even when the inputs logically contain one another. The scalable
counting filter tracks each key's slice, so its `intersection` matches tracked
keys across different slices instead.

Merging adds the insertion counts, and a slice whose combined count exceeds its
planned capacity simply triggers growth before the next insertion, so a merged
filter keeps accepting keys. The merged state also survives a `to_bytes` /
`from_bytes` round trip. Merging into an empty filter copies the source slices
directly instead of OR-ing them into empty storage, and slices the receiver had
already grown are retained; the scalable counting variant likewise copies
counters and metadata instead of rehashing every tracked key. When halving the
target rate for a later slice would underflow to zero, the slice rate is clamped
to the smallest positive `Double`, so every slice stays positive.
`ConcurrentScalableBloomFilter` exposes atomic `merge`, `union`,
`intersection`, `is_subset_of`, and `is_disjoint_from` methods.

## Scalable Counting Bloom Filter

`ScalableCountingBloomFilter` combines slice growth with removable counters. A
new key is inserted into the newest slice, and once that slice reaches its
planned capacity a larger slice is appended. Duplicate insertions stay in the
slice that already owns the key, so each occurrence can be removed separately.

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

The filter tracks a 128-bit hash and the exact multiplicity of every distinct
key so that `remove` knows which slice to update. `count_of` therefore returns
the exact number of insertions made through the filter, or `0` for a key that
was never inserted, even when `contains` reports a false positive. This metadata
grows with the number of distinct keys and is not included in `memory_bytes()`,
which reports only the counter arrays. `insert_if_absent`, the batch helpers,
`copy`, `clear`, and the occupancy statistics mirror the other filters.
`clear` reuses the first slice's counter array, drops later slices, and empties
the tracked-key metadata.
`union` and `merge` rebuild counters from the tracked multiplicities: a key
tracked by both filters keeps the larger multiplicity when both stored it in
the same slice and the sum when they stored it in different slices. Combining a
filter with itself therefore preserves each multiplicity instead of doubling
it. A tracked key whose counters have drained in both inputs stays absent while
keeping its exact multiplicity, so union and merge do not resurrect it.
`intersection` keeps the keys still reported by both filters with the smaller
multiplicity, even when the inputs stored them in different slices. A tracked
key whose counters have drained in either input is treated as absent.
`is_subset_of` also consults the tracked multiplicities across slices, so a
shared key counts as contained even when the two filters placed it in different
slices; `is_disjoint_from` still compares the slice counters because it must
prove that no key can be reported by both. A tracked key whose counters have
drained is no longer reported by `contains`, so the subset check ignores it
instead of requiring the other filter to track the same entry. Count-only
slices, which carry a
conservative insertion count without tracked keys or positive counters, are
treated as empty by set operations: merging such a filter leaves a non-empty
receiver's counters untouched, and a count-only receiver copies the source's
slices and metadata.
The cross-slice fallback covers keys
inserted through the filters. Because slices at different indices use different
hash layouts, it cannot rule out an untracked false-positive key that only the
first filter reports; compare filters that grew in lockstep when a strict
set-inclusion guarantee is required.
`ConcurrentScalableCountingBloomFilter` adds one-mutex atomic operations,
including `intersection`, and a `snapshot()` method.

The backing counters still saturate at 65,535. After a key has been inserted
more times than its counters can distinguish, enough removals can drain those
counters while tracked occurrences remain. `count_of` continues to report the
exact tracked multiplicity and serialization preserves it, but `contains` may
already be `false` and `remove` returns `false` for the remaining occurrences.
`insert_if_absent` consults the tracking metadata as well as the counters, so it
does not add a new occurrence for a key that is still tracked after saturation.
Use `count_of` when tracking exact multiplicity past saturation.

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

Counters saturate at 65535. `CountingBloomFilter::counter_max()` exposes that
limit (and the concurrent and scalable counting wrappers expose the same
constant), which is useful when deciding whether a multiplicity query can still
distinguish additional insertions. A lane selected several times by one key
stores a weighted contribution per insertion, so it can reach its removable cap
after fewer than 65535 insertions. Removing a key that was never inserted can
return `true` on a false positive and disturb other entries, so only remove keys
that are known to be present. `remove_all` returns `true` only if every removal
succeeded; it continues removing the remaining keys after a failure.

`count_of(key)` estimates the current multiplicity of a key from the counters it
selects. When the double-hash sequence visits a slot more than once, that slot
receives one weighted contribution per insertion, so the estimate divides the
smallest counter by the number of times the key selects that position and takes
the smallest normalized value. Other keys that share those slots can make the
estimate too high, but it never drops below the number of insertions unless a
counter has saturated. A position selected more often than a counter can hold
saturates after its first contribution; if every selected position is that wide,
the result falls back to the raw saturated counter because those counters can no
longer distinguish additional insertions:

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

## Compact Counting Bloom Filter

`CompactCountingBloomFilter` is a memory-optimized counting variant. It packs
each counter into a 4-bit nibble instead of a 16-bit value, so an equivalent
filter uses four times less memory than `CountingBloomFilter`:

```moonbit
let compact = @src.CompactCountingBloomFilter::new(1000, 0.01)
let regular = @src.CountingBloomFilter::new(1000, 0.01)
assert_eq(regular.memory_bytes(), compact.memory_bytes() * 4L)
```

The API mirrors `CountingBloomFilter`: `insert`, `contains`, `remove`,
`count_of`, the batch helpers, and the set algebra all behave the same way. The
trade-off is the counter width: counters saturate at `counter_max()`, which is
15, so the filter cannot record more than 15 insertions of the same key.
Insertions past the cap still advance `count()` but leave the counters
unchanged, and `remove` decrements one recorded insertion at a time. When a key's
probes repeat a slot, each insertion adds that repeat count to the lane, so the
lane can reach its removable cap after fewer than 15 insertions:

```moonbit
let filter = @src.CompactCountingBloomFilter::new(1000, 0.01)
for i = 0; i < 20; i = i + 1 {
  filter.insert("task")
}
assert_eq(filter.count_of("task"), @src.CompactCountingBloomFilter::counter_max())
assert_true(filter.remove("task"))
assert_eq(filter.count_of("task"), 14)
```

Saturation also couples keys that share positions. A shared counter holds the
capped sum of their contributions, and increments to a lane already at its
insertion cap are skipped, so removing one key can drain a counter that another
key still relies on. That key then reports `false` from `contains` and `remove`
even though it was inserted. This is inherent to 4-bit counters; avoid
interleaved removals when keys overlap on saturated positions, or use
`CountingBloomFilter` when large multiplicities must survive such removals.

`ConcurrentCompactCountingBloomFilter` wraps the type with the same mutex-based
protection as the other concurrent filters, including atomic `remove`,
`merge`, `union`, `intersection`, and `is_subset_of`.

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
calculation. `capacity()` reports the total number of fingerprint slots,
`remaining_capacity()` reports how many are still free, and `is_full()` is true
once every slot is occupied:

```moonbit
let filter = @src.CuckooFilter::with_size(1, 1)
assert_true(filter.insert("only"))
assert_true(filter.is_full())
assert_eq(filter.remaining_capacity(), 0)
assert_false(filter.insert("another"))
```

A non-zero `remaining_capacity()` does not guarantee that the next insertion
succeeds: cuckoo placement can fail before every slot is occupied, and `insert`
returns `false` in that case. A full filter, however, always rejects further
insertions.

`insert` returns `false` when the filter is full and restores all
evicted fingerprints before returning, so a failed insert cannot lose existing
entries. Before reporting an insertion failure, the filter also searches for an
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
fit, leaving both inputs unchanged. A `None` result can also occur when the
fingerprints fit in the total capacity but no placement is reachable through
their candidate buckets within the bounded eviction and augmenting-path search;
`merge` returns `false` in the same situation without changing the receiver.

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
match left.union(right) {
  Some(combined) => {
    assert_true(left.is_subset_of(combined))
    assert_true(right.is_subset_of(combined))
  }
  None => abort("combined filter is full")
}
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
lock exactly once, and `capacity()`, `remaining_capacity()`, and `is_full()`
report the layout under the lock:

```moonbit
let filter = @src.ConcurrentCuckooFilter::new(1000)
assert_true(filter.insert("session"))
assert_true(filter.contains("session"))
assert_true(filter.remove("session"))
```

Each filter type also has `copy()`, which returns an independent filter. The
concurrent wrappers expose both `copy()` and `snapshot()`, which copy the
underlying filter while holding the lock. A copy remains unchanged if other
threads keep updating the original:

```moonbit
let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
filter.insert("before")
let snapshot = filter.snapshot()
filter.insert("after")
assert_eq(snapshot.count(), 1)
assert_true(snapshot.contains("before"))
```

## Complexity and Memory

Let `k` be `hash_count()`, `m` the number of bits or slots, `s` the number of
slices, and `B` the bucket size. The bounds below describe the backing data
structures; hashing a key costs whatever the key's `Hash` implementation costs.

- `BloomFilter` and `BlockedBloomFilter` probe `k` positions per insert or query
  and store `m` bits in `m / 8` bytes. `BlockedBloomFilter` keeps every
  probe inside one 512-bit block, so a query touches one cache line regardless
  of `k`. An empty filter has no set bit, so queries return `false` and
  occupancy introspection reports zero set bits and `is_full() == false`
  without scanning. A full filter is detected with one scan of the `m / 64`
  backing words when its effective probe walk is wider than that word array,
  after which queries short-circuit to `true` and conditional insertions to
  `false`. Set operations scan the `m / 64` backing words.
- `CountingBloomFilter` and `CompactCountingBloomFilter` update `k` counters,
  deduplicating positions selected more than once, and store 16 bits or 4 bits
  per slot respectively. Inserts and removals reuse a per-filter probe workspace
  sized to `min(k, slot_count)` to avoid allocating temporary position arrays;
  the workspace is omitted from `memory_bytes()` and from serialized data. Small
  slot counts keep that bounded workspace even when `k` is very wide; only
  layouts whose reachable position count exceeds 1,024 fall back to temporary
  arrays, which are themselves capped by the slot count. When the slot count is
  a power of two, inserts, removals, and conditional inserts enumerate one cycle
  once the hash count exceeds it, provided that cycle has at most 16,384
  positions, and assign each position its exact number of occurrences;
  `contains` and `count_of` stop at the cycle without that size limit. Selecting
  that window is constant-time:
  the power-of-two cycle length comes from the lowest set bit of the probe step,
  so a wide hash count does not add a GCD loop to each query. Other slot counts
  keep scanning every probe so later wraparound offsets cannot hide a counter.
  A filter with no positive counters answers `contains` as `false`, `count_of`
  as `0`, and `remove` as `false` without walking the probe sequence, and
  occupancy introspection reports zero occupied slots without scanning, which
  also covers wide non-power-of-two layouts where the cycle shortcut does not
  apply.
  A wide layout whose every slot is positive answers `contains` as `true` and
  makes `insert_if_absent` return `false` after one occupancy scan instead of a
  full probe walk. The scan is selected when the effective probe count exceeds
  both 64 and the number of packed counter words, so a short cycle keeps the
  probe path. Set operations scan the packed counter words unless an operand has
  zero counter mass: the exact mass maintained by every mutation decides
  emptiness and disjointness in constant time, and `merge` copies only the
  insertion count from a count-only source. Clearing an already empty filter
  likewise skips the packed-word scan. Merging into an empty receiver copies the
  packed words directly.
- `CuckooFilter` checks two buckets of `B` fingerprints per query, so a lookup
  is `O(B)` expected. An insert may evict fingerprints and, when random eviction
  does not find room, run a bounded breadth-first search for an augmenting path;
  a failed insert restores every eviction and the eviction state. Storage is one
  byte per slot.
- `ScalableBloomFilter` queries up to `s` slices, while
  `ScalableCountingBloomFilter` also consults its tracked-key map. Inserts append
  a slice when the newest one reaches its planned capacity, so growth is
  amortized. Merges and unions process the slices they combine; merging into an
  empty scalable filter copies the source slices instead of rebuilding them.
  Set checks skip slices whose insertion count is zero, so an empty slice does
  not add an occupancy scan. The scalable counting variant tests each slice's
  exact counter mass instead of scanning its packed counters, and merging or
  checking a count-only source does not walk its counter arrays. Clearing either
  scalable filter reuses the initial slice's backing array and drops later
  slices. The scalable counting map grows with the number of distinct tracked
  keys and is not included in `memory_bytes()`, which reports only counter
  storage.
- The `optimal_size` helpers compute layouts without allocating, and the
  concurrent wrappers forward them without taking the mutex. Batch operations on
  the concurrent wrappers take the lock once for the whole batch.

Definitely empty filters avoid hashing the key for membership queries, and for
the counting variants every selected counter is known to be zero. Cuckoo
`contains`, `count_of`, and `remove` also return immediately once the last
fingerprint has been removed, and a full Cuckoo filter rejects `insert` and
`insert_if_absent` before hashing. A scalable counting filter with no tracked
keys returns `0` from `count_of` and `false` from `remove` without hashing.
Empty batches remain no-ops and never touch the backing storage.

## Occupancy and Storage

Every filter exposes read-only statistics without scanning keys:

- `BloomFilter::set_bit_count()` counts the bits set to one, while
  `fill_ratio()` divides that count by `bit_count()`.
- `CountingBloomFilter::occupied_slot_count()` counts slots with a positive
  counter, while `fill_ratio()` divides that count by `slot_count()`.
  `CompactCountingBloomFilter` exposes the same methods over its nibble-packed
  counters. `ScalableCountingBloomFilter` sums positive counter slots across
  its slices.
- `CuckooFilter::load_factor()` divides the stored fingerprint count by the
  total number of slots, which is reported by `capacity()`.
- `is_full()` reports whether a fixed-size filter has no empty position left:
  `BloomFilter` and `BlockedBloomFilter` check every bit, the counting variants
  check every counter slot, and `CuckooFilter` checks whether every slot holds
  a fingerprint. A full Bloom or counting filter reports every key as present,
  while a full Cuckoo filter always rejects further insertions. Counting and
  Cuckoo filters can still remove entries, and inserts continue to advance
  counters and insertion statistics. The scalable filters grow instead of
  reporting a final full state.
- `estimated_item_count()` derives the number of distinct keys from occupancy
  for the Bloom variants; the scalable variant sums its slice estimates. It
  returns infinity when every slot is occupied.
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

The same methods exist on `BlockedBloomFilter`, `CountingBloomFilter`,
`CompactCountingBloomFilter`, `CuckooFilter`, `ScalableBloomFilter`, and
`ScalableCountingBloomFilter`. The concurrent wrappers also expose
`to_bytes()` and `from_bytes()`, copying the underlying filter while holding the
lock. Hashing uses fixed seeds, so standard
`Hash` implementations produce the same positions in a new process. The Cuckoo
encoding also preserves its deterministic eviction state, so insertions after a
round trip follow the same placement trajectory as the original filter; a zero
eviction state is rejected because it would make every eviction target the same
slot. `from_bytes` panics on truncated data, a different filter type, an
unsupported version, or an invalid configuration.

## Sizing Before Allocation

`BloomFilter::new`, `BlockedBloomFilter::new`, `CountingBloomFilter::new`, and
`CompactCountingBloomFilter::new` derive a layout from a capacity and false
positive rate. When only the resulting size is needed, the matching
`optimal_size` function computes the same layout without allocating the backing
array:

```moonbit
let (bits, hashes) = @src.BloomFilter::optimal_size(10_000, 0.01)
let filter = @src.BloomFilter::new(10_000, 0.01)
assert_eq(bits, filter.bit_count())
assert_eq(hashes, filter.hash_count())
assert_eq(bits.to_int64() / 8L, filter.memory_bytes())
```

The counting and compact counting variants return
`(slot_count, hash_count)`, with the slot count rounded up to a multiple of 16.
Both variants share the same layout, so their `optimal_size` results are
identical. `BlockedBloomFilter::optimal_size` returns a bit count rounded up to
a whole 512-bit block, and `CuckooFilter::optimal_size(expected_items)` returns
the power-of-two `(bucket_count, bucket_size)` pair used by `CuckooFilter::new`.
The scalable filters also expose `optimal_size(expected_items,
false_positive_rate)` for the first slice they allocate. That slice uses half of
the requested false-positive budget, so the helper returns the same
`(bit_count, hash_count)` or `(slot_count, hash_count)` pair as the first slice
of the corresponding constructor. Later slices double the capacity and halve
the rate again, so this helper plans only the initial allocation.
The concurrent wrappers expose the same helpers as
`ConcurrentBloomFilter::optimal_size`,
`ConcurrentBlockedBloomFilter::optimal_size`,
`ConcurrentCountingBloomFilter::optimal_size`,
`ConcurrentCompactCountingBloomFilter::optimal_size`,
`ConcurrentCuckooFilter::optimal_size`,
`ConcurrentScalableBloomFilter::optimal_size`, and
`ConcurrentScalableCountingBloomFilter::optimal_size`, forwarding to the
corresponding base layout without taking the mutex or allocating storage. All of
these functions panic for the same invalid arguments as the constructor they
mirror.

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
insertion and batch queries, conditional insertion, multiplicity queries,
deletion round trips, set operations, disjointness checks, serialization, the
compact counting filter, and the concurrent wrappers:

```bash
moon bench --release
```

To run tests on every backend:

```bash
moon test --target all
```
