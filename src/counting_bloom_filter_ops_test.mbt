///|
test "counting bloom filter union contains keys from both inputs" {
  let left = @src.CountingBloomFilter::with_size(8192, 4)
  let right = @src.CountingBloomFilter::with_size(8192, 4)
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
  combined.clear()
  assert_true(combined.is_empty())
}

///|
test "counting bloom filter union keeps the larger multiplicity" {
  let left = @src.CountingBloomFilter::with_size(8192, 4)
  let right = @src.CountingBloomFilter::with_size(8192, 4)
  left.insert("shared")
  left.insert("shared")
  right.insert("shared")
  let combined = left.union(right)
  assert_true(combined.contains("shared"))
  assert_true(combined.remove("shared"))
  assert_true(combined.contains("shared"))
  assert_true(combined.remove("shared"))
  assert_false(combined.contains("shared"))
}

///|
test "counting bloom filter intersection keeps keys present in both inputs" {
  let left = @src.CountingBloomFilter::with_size(8192, 4)
  let right = @src.CountingBloomFilter::with_size(8192, 4)
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
}

///|
test "counting bloom filter subset compares counters" {
  let once = @src.CountingBloomFilter::with_size(8192, 4)
  let twice = @src.CountingBloomFilter::with_size(8192, 4)
  let keys = ["alpha", "beta", "gamma"]
  once.insert_all(keys)
  twice.insert_all(keys)
  twice.insert_all(keys)
  assert_true(once.is_subset_of(twice))
  assert_false(twice.is_subset_of(once))
  let empty = @src.CountingBloomFilter::with_size(8192, 4)
  assert_true(empty.is_subset_of(once))
  assert_true(once.is_subset_of(once))
}

///|
test "panic counting bloom filter union rejects incompatible sizes" {
  let left = @src.CountingBloomFilter::with_size(16, 2)
  let right = @src.CountingBloomFilter::with_size(32, 2)
  left.union(right) |> ignore
}

///|
test "panic counting bloom filter intersection rejects incompatible hash counts" {
  let left = @src.CountingBloomFilter::with_size(16, 2)
  let right = @src.CountingBloomFilter::with_size(16, 3)
  left.intersection(right) |> ignore
}

///|
test "panic counting bloom filter subset rejects incompatible sizes" {
  let left = @src.CountingBloomFilter::with_size(16, 2)
  let right = @src.CountingBloomFilter::with_size(32, 2)
  left.is_subset_of(right) |> ignore
}

///|
test "panic counting bloom filter union rejects insertion count overflow" {
  let left_bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  left_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let right_bytes = @src.CountingBloomFilter::with_size(16, 1)
    .to_bytes()
    .to_fixedarray()
  right_bytes.unsafe_write_uint32_le(16, 2147483647U)
  let left = @src.CountingBloomFilter::from_bytes(
    Bytes::from_array(left_bytes.exact_view()),
  )
  let right = @src.CountingBloomFilter::from_bytes(
    Bytes::from_array(right_bytes.exact_view()),
  )
  left.union(right) |> ignore
}
