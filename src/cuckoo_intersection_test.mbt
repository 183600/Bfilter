///|
test "cuckoo filter intersection keeps keys present in both inputs" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  let shared = ["shared-1", "shared-2", "shared-3"]
  assert_true(left.insert_all(shared))
  assert_true(left.insert("left-only"))
  assert_true(right.insert_all(shared))
  assert_true(right.insert("right-only"))
  let common = left.intersection(right)
  assert_true(common.contains_all(shared))
  assert_false(common.contains("left-only"))
  assert_false(common.contains("right-only"))
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
}

///|
test "cuckoo filter intersection of disjoint filters is empty" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  let common = left.intersection(right)
  assert_true(common.is_empty())
  assert_eq(common.count(), 0)
}

///|
test "cuckoo filter intersection respects duplicate multiplicities" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("shared"))
  assert_true(left.insert("shared"))
  assert_true(left.insert("shared"))
  assert_true(right.insert("shared"))
  assert_true(right.insert("shared"))
  let common = left.intersection(right)
  assert_eq(common.count_of("shared"), 2)
  assert_eq(common.count(), 2)
  assert_true(common.remove("shared"))
  assert_eq(common.count(), 1)
  assert_true(common.remove("shared"))
  assert_false(common.contains("shared"))
}

///|
test "cuckoo filter intersection leaves the inputs unchanged" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("shared"))
  assert_true(left.insert("left-only"))
  assert_true(right.insert("shared"))
  assert_true(right.insert("right-only"))
  let common = left.intersection(right)
  assert_true(common.remove("shared"))
  assert_true(left.contains("shared"))
  assert_true(right.contains("shared"))
  assert_eq(left.count(), 2)
  assert_eq(right.count(), 2)
}

///|
test "cuckoo filter intersection with itself keeps every entry" {
  let filter = @src.CuckooFilter::with_size(64, 4)
  let keys = ["a", "b", "c", "d"]
  assert_true(filter.insert_all(keys))
  let common = filter.intersection(filter.copy())
  assert_true(common.contains_all(keys))
  assert_eq(common.count(), 4)
  assert_true(filter.is_subset_of(common))
}

///|
test "concurrent cuckoo filter intersects a snapshot" {
  let left = @src.ConcurrentCuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("shared"))
  assert_true(left.insert("left-only"))
  assert_true(right.insert("shared"))
  assert_true(right.insert("right-only"))
  let common = left.intersection(right)
  assert_true(common.contains("shared"))
  assert_false(common.contains("left-only"))
  assert_false(common.contains("right-only"))
  assert_true(left.contains("left-only"))
}

///|
test "panic cuckoo filter intersection rejects incompatible layouts" {
  let left = @src.CuckooFilter::with_size(8, 4)
  let right = @src.CuckooFilter::with_size(16, 4)
  left.intersection(right) |> ignore
}
