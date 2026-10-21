///|
test "cuckoo intersection scales to many distinct fingerprints" {
  let left = @src.CuckooFilter::with_size(2048, 4)
  let right = @src.CuckooFilter::with_size(2048, 4)
  let keys : Array[String] = Array::makei(2000, i => {
    "intersection-key-" + i.to_string()
  })
  assert_true(left.insert_all(keys))
  assert_true(right.insert_all(keys))
  let common = left.intersection(right)
  assert_eq(common.count(), left.count())
  assert_true(common.contains_all(keys))
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
  let restored = @src.CuckooFilter::from_bytes(common.to_bytes())
  assert_eq(restored.count(), common.count())
  assert_true(restored.contains_all(keys))
}
