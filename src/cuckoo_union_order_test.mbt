///|
test "cuckoo union retries with reversed inputs when placement is blocked" {
  let left = @src.CuckooFilter::with_size(8, 2)
  let right = @src.CuckooFilter::with_size(8, 2)
  for key = 0; key < 14; key = key + 1 {
    if key != 4 {
      assert_true(left.insert(key))
    }
  }
  assert_true(right.insert(4))
  assert_eq(left.count(), 13)
  assert_eq(right.count(), 1)
  let combined = match left.union(right) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_eq(combined.count(), 14)
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  let merged = left.copy()
  assert_true(merged.merge(right))
  assert_eq(merged.count(), 14)
  assert_true(left.is_subset_of(merged))
  assert_true(right.is_subset_of(merged))
}

///|
test "cuckoo union rebuilds when neither existing placement can absorb the other" {
  let left = @src.CuckooFilter::with_size(8, 2)
  let right = @src.CuckooFilter::with_size(8, 2)
  let mut seed = 1881
  for step = 0; step < 30; step = step + 1 {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    let key = seed % 20
    let which = seed / 31 % 4
    if which == 0 {
      ignore(left.insert(key))
    } else if which == 1 {
      ignore(right.insert(key))
    } else if which == 2 {
      ignore(left.remove(key))
    } else {
      ignore(right.remove(key))
    }
  }
  assert_eq(left.count(), 6)
  assert_eq(right.count(), 4)
  let combined = match left.union(right) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_eq(combined.count(), 10)
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
}
