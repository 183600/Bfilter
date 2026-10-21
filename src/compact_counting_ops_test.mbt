///|
test "compact counting filter batch operations" {
  let filter = @src.CompactCountingBloomFilter::new(100, 0.01)
  let keys = ["a", "b", "c", "d", "e"]
  filter.insert_all(keys)
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains_any(["missing", "c"]))
  assert_false(filter.contains_any(["missing-1", "missing-2"]))
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.insert_all_if_absent(["f", "g"]), 2)
  assert_true(filter.remove_all(["a", "b"]))
  assert_false(filter.contains("a"))
  assert_true(filter.contains_all(["c", "d", "e", "f", "g"]))
}

///|
test "compact counting filter union merges multiplicities" {
  let left = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let right = @src.CompactCountingBloomFilter::with_size(1024, 4)
  left.insert_all(["shared", "shared", "left"])
  right.insert_all(["shared", "right"])
  let combined = left.union(right)
  assert_eq(combined.count(), left.count() + right.count())
  assert_eq(combined.count_of("shared"), 2)
  assert_true(combined.contains("left"))
  assert_true(combined.contains("right"))
  assert_false(left.contains("right"))
  assert_false(right.contains("left"))
}

///|
test "compact counting filter merge updates the receiver in place" {
  let left = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let right = @src.CompactCountingBloomFilter::with_size(1024, 4)
  left.insert("left")
  right.insert("right")
  left.merge(right)
  assert_true(left.contains("left"))
  assert_true(left.contains("right"))
  assert_eq(left.count(), 2)
  assert_true(left.is_subset_of(left.union(right)))
}

///|
test "compact counting filter intersection keeps shared keys" {
  let left = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let right = @src.CompactCountingBloomFilter::with_size(1024, 4)
  left.insert_all(["shared", "left-only"])
  right.insert_all(["shared", "right-only"])
  let common = left.intersection(right)
  assert_true(common.contains("shared"))
  assert_false(common.contains("left-only"))
  assert_false(common.contains("right-only"))
  assert_eq(common.count(), left.count().min(right.count()))
}

///|
test "compact counting filter subset follows counter values" {
  let small = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let large = small.copy()
  small.insert_all(["a", "b"])
  large.insert_all(["a", "b", "c"])
  assert_true(small.is_subset_of(large))
  assert_false(large.is_subset_of(small))
  assert_true(small.is_subset_of(small))
}

///|
test "panic compact counting set operations reject different layouts" {
  let left = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let right = @src.CompactCountingBloomFilter::with_size(1024, 3)
  left.merge(right)
  left.union(right) |> ignore
  left.intersection(right) |> ignore
  left.is_subset_of(right) |> ignore
}
