///|
test "cuckoo union retry keeps a nonzero eviction state" {
  // Mixing the retry attempt into this state lands on zero for the first
  // attempt. The result must still be a valid filter that serializes.
  let first = CuckooFilter::with_size(8, 4)
  first.random_state = 0x2545F4914F6CDD1DUL
  let second = CuckooFilter::with_size(8, 4)
  assert_true(second.insert("payload"))
  let result = match CuckooFilter::retry_union(first, second) {
    Some(filter) => filter
    None => abort("retry unexpectedly failed")
  }
  assert_true(result.random_state != 0UL)
  let restored = CuckooFilter::from_bytes(result.to_bytes())
  assert_eq(restored.random_state, result.random_state)
  assert_true(restored.contains("payload"))
}

///|
test "cuckoo union of two empty filters keeps the receiver state" {
  let left = CuckooFilter::with_size(8, 4)
  left.random_state = 0x13579BDF2468ACE0UL
  let right = CuckooFilter::with_size(8, 4)
  right.random_state = 0x0FEDCBA987654321UL
  let combined = match left.union(right) {
    Some(filter) => filter
    None => abort("empty union unexpectedly failed")
  }
  assert_eq(combined.to_bytes(), left.to_bytes())
  let merged = left.copy()
  assert_true(merged.merge(right))
  assert_eq(merged.to_bytes(), left.to_bytes())
}
