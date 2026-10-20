///|
test "cuckoo merge adopts the union eviction state" {
  let left = CuckooFilter::with_size(8, 2)
  let right = CuckooFilter::with_size(8, 2)
  for key = 0; key < 14; key = key + 1 {
    if key != 4 {
      assert_true(left.insert(key))
    }
  }
  assert_true(right.insert(4))
  let combined = match left.union(right) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  let merged = left.copy()
  assert_true(merged.merge(right))
  assert_eq(merged.random_state, combined.random_state)
}
