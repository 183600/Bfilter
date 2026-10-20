///|
test "bloom filter union contains keys from both inputs" {
  let left = @src.BloomFilter::with_size(8192, 4)
  let right = @src.BloomFilter::with_size(8192, 4)
  let left_keys = ["a", "b", "c"]
  let right_keys = ["d", "e", "f"]
  left.insert_all(left_keys)
  right.insert_all(right_keys)
  let combined = left.union(right)
  assert_true(combined.contains_all(left_keys))
  assert_true(combined.contains_all(right_keys))
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  assert_eq(combined.count(), left.count() + right.count())
  assert_true(combined.set_bit_count() >= left.set_bit_count())
  assert_true(combined.set_bit_count() >= right.set_bit_count())
}

///|
test "bloom filter intersection keeps keys present in both inputs" {
  let left = @src.BloomFilter::with_size(8192, 4)
  let right = @src.BloomFilter::with_size(8192, 4)
  let shared = ["shared-1", "shared-2", "shared-3"]
  left.insert_all(shared)
  left.insert("left-only")
  right.insert_all(shared)
  right.insert("right-only")
  let common = left.intersection(right)
  assert_true(common.contains_all(shared))
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
  assert_eq(common.count(), left.count().min(right.count()))
  assert_true(common.set_bit_count() <= left.set_bit_count())
  assert_true(common.set_bit_count() <= right.set_bit_count())
}

///|
test "bloom filter subset checks empty and disjoint filters" {
  let empty = @src.BloomFilter::with_size(512, 3)
  let filled = @src.BloomFilter::with_size(512, 3)
  filled.insert("value")
  assert_true(empty.is_subset_of(filled))
  assert_false(filled.is_subset_of(empty))
  assert_true(empty.is_subset_of(empty))
}

///|
test "panic bloom filter union rejects incompatible sizes" {
  let left = @src.BloomFilter::with_size(64, 2)
  let right = @src.BloomFilter::with_size(128, 2)
  left.union(right) |> ignore
}

///|
test "panic bloom filter intersection rejects incompatible hash counts" {
  let left = @src.BloomFilter::with_size(64, 2)
  let right = @src.BloomFilter::with_size(64, 3)
  left.intersection(right) |> ignore
}

///|
test "panic bloom filter subset rejects incompatible sizes" {
  let left = @src.BloomFilter::with_size(64, 2)
  let right = @src.BloomFilter::with_size(128, 2)
  left.is_subset_of(right) |> ignore
}

///|
test "panic bloom filter union rejects insertion count overflow" {
  let left_bytes = @src.BloomFilter::with_size(64, 1).to_bytes().to_fixedarray()
  left_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let right_bytes = @src.BloomFilter::with_size(64, 1)
    .to_bytes()
    .to_fixedarray()
  right_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let left = @src.BloomFilter::from_bytes(
    Bytes::from_array(left_bytes.exact_view()),
  )
  let right = @src.BloomFilter::from_bytes(
    Bytes::from_array(right_bytes.exact_view()),
  )
  left.union(right) |> ignore
}
