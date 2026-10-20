///|
test "cuckoo filter union contains keys from both inputs" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  let left_keys = ["a", "b", "c", "d", "e"]
  let right_keys = ["f", "g", "h", "i", "j"]
  assert_true(left.insert_all(left_keys))
  assert_true(right.insert_all(right_keys))
  let combined = match left.union(right) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_true(combined.contains_all(left_keys))
  assert_true(combined.contains_all(right_keys))
  assert_eq(combined.count(), left.count() + right.count())
  assert_true(combined.remove("a"))
  assert_false(combined.contains("a"))
  assert_true(left.contains("a"))
  assert_eq(left.count(), 5)
}

///|
test "cuckoo filter union reports when the result cannot fit" {
  let left = @src.CuckooFilter::with_size(1, 1)
  let right = @src.CuckooFilter::with_size(1, 1)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  assert_true(left.union(right) is None)
  assert_eq(left.count(), 1)
  assert_eq(right.count(), 1)
  assert_true(left.contains("left"))
  assert_true(right.contains("right"))
}

///|
test "panic cuckoo filter union rejects incompatible layouts" {
  let left = @src.CuckooFilter::with_size(8, 4)
  let right = @src.CuckooFilter::with_size(16, 4)
  left.union(right) |> ignore
}
