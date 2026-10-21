///|
test "cuckoo union combines partially full filters" {
  let layouts : Array[(Int32, Int32)] = [
    (2, 2),
    (4, 2),
    (8, 2),
    (16, 4),
    (32, 4),
  ]
  for layout in layouts {
    let (bucket_count, bucket_size) = layout
    let capacity = bucket_count * bucket_size
    for round = 1; round <= 200; round = round + 1 {
      let left = @src.CuckooFilter::with_size(bucket_count, bucket_size)
      let right = @src.CuckooFilter::with_size(bucket_count, bucket_size)
      let mut seed = round * 7919 + 11
      let left_target = capacity * 9 / 20
      let right_target = capacity * 9 / 20
      let mut left_added = 0
      let mut right_added = 0
      let mut key = 0
      while left_added < left_target || right_added < right_target {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        key = key + 1
        if left_added < left_target && left.insert("l-" + key.to_string()) {
          left_added = left_added + 1
        }
        if right_added < right_target && right.insert("r-" + key.to_string()) {
          right_added = right_added + 1
        }
      }
      assert_eq(left.count() + right.count(), left_target + right_target)
      let combined = match left.union(right) {
        Some(filter) => filter
        None => abort("union unexpectedly ran out of space")
      }
      assert_eq(combined.count(), left_target + right_target)
      assert_true(left.is_subset_of(combined))
      assert_true(right.is_subset_of(combined))
    }
  }
}
