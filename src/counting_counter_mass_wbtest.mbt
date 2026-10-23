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
