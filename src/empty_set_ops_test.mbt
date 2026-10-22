///|
test "bloom set operations short-circuit on an empty operand" {
  let empty = @src.BloomFilter::with_size(4096, 4)
  let full = @src.BloomFilter::with_size(4096, 4)
  full.insert_all(["alpha", "beta"])

  let left_empty = empty.intersection(full)
  let right_empty = full.intersection(empty)
  assert_eq(left_empty.count(), 0)
  assert_eq(right_empty.count(), 0)
  assert_eq(left_empty.to_bytes(), empty.to_bytes())
  assert_eq(right_empty.to_bytes(), empty.to_bytes())
  assert_true(empty.is_subset_of(full))
  assert_false(full.is_subset_of(empty))
  assert_true(empty.is_disjoint_from(full))
  assert_true(full.is_disjoint_from(empty))
}

///|
test "blocked bloom set operations short-circuit on an empty operand" {
  let empty = @src.BlockedBloomFilter::with_size(4096, 4)
  let full = @src.BlockedBloomFilter::with_size(4096, 4)
  full.insert_all(["alpha", "beta"])

  let left_empty = empty.intersection(full)
  let right_empty = full.intersection(empty)
  assert_eq(left_empty.count(), 0)
  assert_eq(right_empty.count(), 0)
  assert_eq(left_empty.to_bytes(), empty.to_bytes())
  assert_eq(right_empty.to_bytes(), empty.to_bytes())
  assert_true(empty.is_subset_of(full))
  assert_false(full.is_subset_of(empty))
  assert_true(empty.is_disjoint_from(full))
  assert_true(full.is_disjoint_from(empty))
}

///|
test "counting set operations short-circuit on an empty operand" {
  let empty = @src.CountingBloomFilter::with_size(4096, 4)
  let full = @src.CountingBloomFilter::with_size(4096, 4)
  full.insert_all(["alpha", "alpha", "beta"])

  let left_empty = empty.intersection(full)
  let right_empty = full.intersection(empty)
  assert_eq(left_empty.count(), 0)
  assert_eq(right_empty.count(), 0)
  assert_eq(left_empty.to_bytes(), empty.to_bytes())
  assert_eq(right_empty.to_bytes(), empty.to_bytes())
  assert_true(empty.is_subset_of(full))
  assert_false(full.is_subset_of(empty))
  assert_true(empty.is_disjoint_from(full))
  assert_true(full.is_disjoint_from(empty))
  assert_eq(left_empty.occupied_slot_count(), 0)
  assert_eq(right_empty.occupied_slot_count(), 0)
}

///|
test "compact counting set operations short-circuit on an empty operand" {
  let empty = @src.CompactCountingBloomFilter::with_size(4096, 4)
  let full = @src.CompactCountingBloomFilter::with_size(4096, 4)
  full.insert_all(["alpha", "alpha", "beta"])

  let left_empty = empty.intersection(full)
  let right_empty = full.intersection(empty)
  assert_eq(left_empty.count(), 0)
  assert_eq(right_empty.count(), 0)
  assert_eq(left_empty.to_bytes(), empty.to_bytes())
  assert_eq(right_empty.to_bytes(), empty.to_bytes())
  assert_true(empty.is_subset_of(full))
  assert_false(full.is_subset_of(empty))
  assert_true(empty.is_disjoint_from(full))
  assert_true(full.is_disjoint_from(empty))
  assert_eq(left_empty.occupied_slot_count(), 0)
  assert_eq(right_empty.occupied_slot_count(), 0)
}
