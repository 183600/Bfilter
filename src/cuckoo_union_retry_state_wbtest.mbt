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
