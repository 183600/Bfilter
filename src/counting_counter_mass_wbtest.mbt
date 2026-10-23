///|
/// Sum the packed 16-bit counters independently of the maintained mass field.
fn counting_scanned_counter_mass(filter : CountingBloomFilter) -> UInt64 {
  let mut total = 0UL
  for i = 0; i < filter.counters.length(); i = i + 1 {
    total = total + counting_word_mass(filter.counters[i])
  }
  total
}

///|
/// Sum the packed 4-bit counters independently of the maintained mass field.
fn compact_scanned_counter_mass(filter : CompactCountingBloomFilter) -> UInt64 {
  let mut total = 0UL
  for i = 0; i < filter.counters.length(); i = i + 1 {
    total = total + compact_word_mass(filter.counters[i])
  }
  total
}

///|
test "counting counter mass matches packed counters through mutations" {
  let left = CountingBloomFilter::with_size(256, 4)
  left.insert("alpha")
  left.insert("alpha")
  left.insert("beta")
  assert_eq(left.counter_mass, counting_scanned_counter_mass(left))
  assert_true(left.has_positive_counter())

  let right = CountingBloomFilter::with_size(256, 4)
  right.insert("beta")
  right.insert("gamma")

  let union = left.union(right)
  assert_eq(union.counter_mass, counting_scanned_counter_mass(union))
  assert_true(union.has_positive_counter())

  let common = left.intersection(right)
  assert_eq(common.counter_mass, counting_scanned_counter_mass(common))

  let drained = CountingBloomFilter::with_size(256, 4)
  drained.insert("only")
  assert_true(drained.has_positive_counter())
  assert_true(drained.remove("only"))
  assert_eq(drained.counter_mass, 0UL)
  assert_eq(drained.counter_mass, counting_scanned_counter_mass(drained))
  assert_false(drained.has_positive_counter())

  drained.clear()
  assert_eq(drained.counter_mass, 0UL)
  assert_false(drained.has_positive_counter())
}

///|
test "compact counting counter mass matches packed counters through mutations" {
  let left = CompactCountingBloomFilter::with_size(256, 4)
  left.insert("alpha")
  left.insert("alpha")
  left.insert("beta")
  assert_eq(left.counter_mass, compact_scanned_counter_mass(left))

  let right = CompactCountingBloomFilter::with_size(256, 4)
  right.insert("beta")
  right.insert("gamma")

  let union = left.union(right)
  assert_eq(union.counter_mass, compact_scanned_counter_mass(union))

  let common = left.intersection(right)
  assert_eq(common.counter_mass, compact_scanned_counter_mass(common))

  let drained = CompactCountingBloomFilter::with_size(256, 4)
  drained.insert("only")
  assert_true(drained.remove("only"))
  assert_eq(drained.counter_mass, 0UL)
  assert_eq(drained.counter_mass, compact_scanned_counter_mass(drained))

  drained.clear()
  assert_eq(drained.counter_mass, 0UL)
}

///|
test "zero-mass counting filters short-circuit set operations" {
  let drained = CountingBloomFilter::with_size(256, 4)
  drained.insert("only")
  assert_true(drained.remove("only"))
  let other = CountingBloomFilter::with_size(256, 4)
  other.insert("kept")

  assert_true(drained.is_subset_of(other))
  assert_false(other.is_subset_of(drained))
  assert_true(drained.is_disjoint_from(other))
  assert_true(other.is_disjoint_from(drained))
  assert_eq(drained.intersection(other).count(), 0)
  assert_eq(other.intersection(drained).count(), 0)
  let combined = drained.union(other)
  assert_true(combined.contains("kept"))
  assert_eq(combined.count(), other.count())

  let unchanged = other.copy()
  let before = unchanged.to_bytes()
  unchanged.merge(drained)
  assert_eq(unchanged.to_bytes(), before)
}

///|
test "zero-mass compact counting filters short-circuit set operations" {
  let drained = CompactCountingBloomFilter::with_size(256, 4)
  drained.insert("only")
  assert_true(drained.remove("only"))
  let other = CompactCountingBloomFilter::with_size(256, 4)
  other.insert("kept")

  assert_true(drained.is_subset_of(other))
  assert_false(other.is_subset_of(drained))
  assert_true(drained.is_disjoint_from(other))
  assert_true(other.is_disjoint_from(drained))
  assert_eq(drained.intersection(other).count(), 0)
  assert_eq(other.intersection(drained).count(), 0)
  let combined = drained.union(other)
  assert_true(combined.contains("kept"))
  assert_eq(combined.count(), other.count())

  let unchanged = other.copy()
  let before = unchanged.to_bytes()
  unchanged.merge(drained)
  assert_eq(unchanged.to_bytes(), before)
}

///|
test "scalable counting positivity follows exact slice masses" {
  let empty = ScalableCountingBloomFilter::new(2, 0.01)
  assert_false(empty.has_positive_counters())

  let count_only = ScalableCountingBloomFilter::new(2, 0.01)
  count_only.slices[0].inserted = 3
  count_only.inserted = 3
  assert_false(count_only.has_positive_counters())
  assert_true(count_only.is_subset_of(empty))
  assert_true(count_only.is_disjoint_from(empty))

  let live = ScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    live.insert("key-" + i.to_string())
  }
  assert_true(live.has_positive_counters())
  assert_true(live.occupied_slot_count() > 0L)

  assert_true(count_only.is_subset_of(live))
  assert_true(count_only.is_disjoint_from(live))
  assert_false(live.is_subset_of(count_only))

  // A count-only source contributes no counters, so merging it leaves a live
  // receiver's byte representation untouched.
  let before = live.to_bytes()
  live.merge(count_only)
  assert_eq(live.to_bytes(), before)
}

///|
test "count-only counting sources merge without touching counters" {
  let count_only : CountingBloomFilter = {
    counters: FixedArray::make(4, 0UL),
    slot_count: 16,
    hash_count: 1,
    inserted: 5,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(1, 0),
    probe_counts: FixedArray::make(1, 0),
  }
  assert_false(count_only.has_positive_counter())
  assert_true(count_only.is_subset_of(CountingBloomFilter::with_size(16, 1)))
  assert_true(
    count_only.is_disjoint_from(CountingBloomFilter::with_size(16, 1)),
  )

  let receiver = CountingBloomFilter::with_size(16, 1)
  receiver.insert("kept")
  let before_mass = receiver.counter_mass
  let before_occupied = receiver.occupied_slot_count()
  let before_count = receiver.count()
  receiver.merge(count_only)
  assert_eq(receiver.counter_mass, before_mass)
  assert_eq(receiver.occupied_slot_count(), before_occupied)
  assert_eq(receiver.count(), before_count + 5)
  assert_true(receiver.contains("kept"))
  assert_true(count_only.is_subset_of(receiver))
  assert_false(receiver.is_subset_of(count_only))
  assert_true(count_only.is_disjoint_from(receiver))

  let merged_count = receiver.count()
  let combined = count_only.union(receiver)
  assert_eq(combined.count(), merged_count + 5)
  assert_true(combined.contains("kept"))
}

///|
test "count-only compact counting sources merge without touching counters" {
  let count_only : CompactCountingBloomFilter = {
    counters: FixedArray::make(1, 0UL),
    slot_count: 16,
    hash_count: 1,
    inserted: 5,
    counter_mass: 0UL,
    probe_positions: FixedArray::make(1, 0),
    probe_counts: FixedArray::make(1, 0),
  }
  assert_true(
    count_only.is_subset_of(CompactCountingBloomFilter::with_size(16, 1)),
  )
  assert_true(
    count_only.is_disjoint_from(CompactCountingBloomFilter::with_size(16, 1)),
  )

  let receiver = CompactCountingBloomFilter::with_size(16, 1)
  receiver.insert("kept")
  let before_mass = receiver.counter_mass
  let before_occupied = receiver.occupied_slot_count()
  let before_count = receiver.count()
  receiver.merge(count_only)
  assert_eq(receiver.counter_mass, before_mass)
  assert_eq(receiver.occupied_slot_count(), before_occupied)
  assert_eq(receiver.count(), before_count + 5)
  assert_true(receiver.contains("kept"))
  assert_false(receiver.is_subset_of(count_only))
  assert_true(count_only.is_disjoint_from(receiver))

  let merged_count = receiver.count()
  let combined = count_only.union(receiver)
  assert_eq(combined.count(), merged_count + 5)
  assert_true(combined.contains("kept"))
}


///|
test "counting subset checks use exact counter mass without false positives" {
  let smaller = CountingBloomFilter::with_size(256, 4)
  smaller.insert("alpha")
  let larger = CountingBloomFilter::with_size(256, 4)
  larger.insert_all(["alpha", "beta", "gamma"])
  assert_true(smaller.counter_mass < larger.counter_mass)
  assert_true(smaller.is_subset_of(larger))
  assert_false(larger.is_subset_of(smaller))

  // Equal mass must still fall through to the packed lane comparison; two
  // different keys can occupy disjoint slots with the same total mass.
  let left = CountingBloomFilter::with_size(256, 4)
  left.insert("left-key")
  let right = CountingBloomFilter::with_size(256, 4)
  right.insert("right-key")
  assert_eq(left.counter_mass, right.counter_mass)
  assert_false(left.is_subset_of(right))
  assert_true(left.is_subset_of(left.union(right)))
}

///|
test "compact counting subset checks use exact counter mass without false positives" {
  let smaller = CompactCountingBloomFilter::with_size(256, 4)
  smaller.insert("alpha")
  let larger = CompactCountingBloomFilter::with_size(256, 4)
  larger.insert_all(["alpha", "beta", "gamma"])
  assert_true(smaller.counter_mass < larger.counter_mass)
  assert_true(smaller.is_subset_of(larger))
  assert_false(larger.is_subset_of(smaller))

  let left = CompactCountingBloomFilter::with_size(256, 4)
  left.insert("left-key")
  let right = CompactCountingBloomFilter::with_size(256, 4)
  right.insert("right-key")
  assert_eq(left.counter_mass, right.counter_mass)
  assert_false(left.is_subset_of(right))
  assert_true(left.is_subset_of(left.union(right)))
}
