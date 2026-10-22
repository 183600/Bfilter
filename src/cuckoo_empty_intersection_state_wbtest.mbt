///|
test "cuckoo empty intersections keep the receiver eviction state" {
  let left = CuckooFilter::with_size(8, 4)
  left.random_state = 0x13579BDF2468ACE0UL
  let right = CuckooFilter::with_size(8, 4)
  right.random_state = 0x0FEDCBA987654321UL

  let both_empty = left.intersection(right)
  assert_true(both_empty.is_empty())
  assert_eq(both_empty.random_state, left.random_state)
  assert_eq(both_empty.to_bytes(), left.to_bytes())

  let filled = CuckooFilter::with_size(8, 4)
  filled.random_state = 0x2468ACE013579BDFUL
  assert_true(filled.insert("present"))
  let empty_on_left = left.intersection(filled)
  assert_true(empty_on_left.is_empty())
  assert_eq(empty_on_left.random_state, left.random_state)
  assert_eq(empty_on_left.to_bytes(), left.to_bytes())

  let empty_on_right = filled.intersection(left)
  assert_true(empty_on_right.is_empty())
  assert_eq(empty_on_right.random_state, filled.random_state)
  assert_eq(empty_on_right.bucket_count(), filled.bucket_count())
  assert_eq(empty_on_right.bucket_size(), filled.bucket_size())
  let restored = CuckooFilter::from_bytes(empty_on_right.to_bytes())
  assert_eq(restored.random_state, filled.random_state)
  assert_true(restored.is_empty())
}
