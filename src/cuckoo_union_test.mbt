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
test "cuckoo filter union with an empty input keeps stored fingerprints" {
  let empty = @src.CuckooFilter::with_size(64, 4)
  let filled = @src.CuckooFilter::with_size(64, 4)
  assert_true(filled.insert_all(["a", "b", "c"]))
  let forward = match empty.union(filled) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_eq(forward.count(), filled.count())
  assert_true(forward.contains_all(["a", "b", "c"]))
  assert_eq(forward.to_bytes(), filled.to_bytes())
  let backward = match filled.union(empty) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_eq(backward.count(), filled.count())
  assert_eq(backward.to_bytes(), filled.to_bytes())
  let both = match empty.union(empty) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_true(both.is_empty())
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

///|
test "cuckoo filter merge updates the receiver in place" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  assert_true(left.merge(right))
  assert_true(left.contains("left"))
  assert_true(left.contains("right"))
  assert_eq(left.count(), 2)
  assert_true(right.remove("right"))
  assert_true(left.remove("left"))
}

///|
test "cuckoo filter merge failure preserves the receiver" {
  let left = @src.CuckooFilter::with_size(1, 1)
  let right = @src.CuckooFilter::with_size(1, 1)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  assert_false(left.merge(right))
  assert_eq(left.count(), 1)
  assert_true(left.contains("left"))
}

///|
test "concurrent cuckoo filter merges a snapshot" {
  let left = @src.ConcurrentCuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  assert_true(left.merge(right))
  assert_true(left.contains("left"))
  assert_true(left.contains("right"))
  assert_eq(left.count(), 2)
}

///|
test "cuckoo filter union keeps duplicate fingerprints" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("shared"))
  assert_true(left.insert("shared"))
  assert_true(right.insert("shared"))
  let combined = match left.union(right) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_eq(combined.count(), 3)
  assert_true(combined.remove("shared"))
  assert_true(combined.remove("shared"))
  assert_true(combined.remove("shared"))
  assert_false(combined.contains("shared"))
}

///|
test "cuckoo filter subset checks fingerprints across candidate buckets" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  let shared = ["shared-1", "shared-2", "shared-3"]
  assert_true(left.insert_all(shared))
  assert_true(left.insert("left-only"))
  assert_true(right.insert_all(shared))
  assert_true(right.insert("right-only"))
  let combined = match left.union(right) {
    Some(filter) => filter
    None => abort("union unexpectedly ran out of space")
  }
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  let empty = @src.CuckooFilter::with_size(64, 4)
  assert_true(empty.is_subset_of(left))
  assert_false(left.is_subset_of(empty))
}

///|
test "cuckoo filter subset compares duplicate multiplicities" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("shared"))
  assert_true(left.insert("shared"))
  assert_true(right.insert("shared"))
  assert_false(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
}

///|
test "cuckoo filter subset and disjointness short-circuit empty filters" {
  let empty = @src.CuckooFilter::with_size(64, 4)
  let full = @src.CuckooFilter::with_size(64, 4)
  assert_true(full.insert_all(["a", "b", "c"]))
  assert_true(empty.is_subset_of(full))
  assert_false(full.is_subset_of(empty))
  assert_true(empty.is_disjoint_from(full))
  assert_true(full.is_disjoint_from(empty))
  assert_true(empty.is_disjoint_from(empty))
}

///|
test "cuckoo filter subset and disjointness handle duplicate copies" {
  let left = @src.CuckooFilter::with_size(8, 4)
  let right = @src.CuckooFilter::with_size(8, 4)
  for i = 0; i < 4; i = i + 1 {
    assert_true(left.insert("shared"))
    assert_true(right.insert("shared"))
  }
  assert_true(left.is_subset_of(right))
  assert_true(right.is_subset_of(left))
  assert_false(left.is_disjoint_from(right))
  assert_true(right.remove("shared"))
  assert_false(left.is_subset_of(right))
  assert_false(left.is_disjoint_from(right))
  for i = 0; i < 3; i = i + 1 {
    assert_true(right.remove("shared"))
  }
  assert_true(left.is_disjoint_from(right))
}

///|
test "panic cuckoo filter subset rejects incompatible layouts" {
  let left = @src.CuckooFilter::with_size(8, 4)
  let right = @src.CuckooFilter::with_size(16, 4)
  left.is_subset_of(right) |> ignore
}

///|
test "cuckoo filter union rejects a combined count above capacity" {
  let left = @src.CuckooFilter::with_size(2, 2)
  let right = @src.CuckooFilter::with_size(2, 2)
  assert_true(left.insert_all(["a", "b", "c"]))
  assert_true(right.insert_all(["d", "e"]))
  assert_true(left.union(right) is None)
  assert_eq(left.count(), 3)
  assert_eq(right.count(), 2)
  assert_true(left.contains_all(["a", "b", "c"]))
  assert_true(right.contains_all(["d", "e"]))
}
