///|
/// Set-operation law checks: merge/union/intersection/is_subset/is_disjoint
/// must agree with direct membership for inserted keys, and empty operands must
/// short-circuit without scanning.
///|
test "fuzz bloom set operations agree with membership" {
  let f1 = @src.BloomFilter::with_size(4096, 6)
  let f2 = @src.BloomFilter::with_size(4096, 6)
  for i = 0; i < 200; i = i + 1 { f1.insert("a-" + i.to_string()) }
  for i = 100; i < 300; i = i + 1 { f2.insert("b-" + i.to_string()) }
  // overlap: a-100..a-199 vs b-100..b-199 are different strings; use same keys
  let shared = ["s-0", "s-1", "s-2"]
  for s in shared { f1.insert(s); f2.insert(s) }

  let u = f1.union(f2)
  for s in shared { assert_true(u.contains(s)) }
  for i = 0; i < 200; i = i + 1 { assert_true(u.contains("a-" + i.to_string())) }
  for i = 100; i < 300; i = i + 1 { assert_true(u.contains("b-" + i.to_string())) }
  assert_true(f1.is_subset_of(u))
  assert_true(f2.is_subset_of(u))

  let inter = f1.intersection(f2)
  for s in shared { assert_true(inter.contains(s)) }
  // non-shared keys must not survive intersection
  assert_false(inter.contains("a-0"))
  assert_false(inter.contains("b-100"))

  // Empty short circuits
  let empty = @src.BloomFilter::with_size(4096, 6)
  assert_true(f1.is_disjoint_from(empty))
  assert_true(empty.is_disjoint_from(f1))
  assert_true(empty.is_subset_of(f1))
  assert_false(f1.is_subset_of(empty))
  let u2 = empty.union(f1)
  assert_true(u2.contains("a-0"))
  assert_eq(u2.count(), f1.count())

  // merge into empty copies storage
  let into_empty = @src.BloomFilter::with_size(4096, 6)
  into_empty.merge(f1)
  assert_true(into_empty.contains("a-0"))
  assert_eq(into_empty.count(), f1.count())
}

///|
/// Counting filter set operations preserve the keys of both inputs.
test "fuzz counting set operations preserve keys" {
  let f1 = @src.CountingBloomFilter::with_size(4096, 6)
  let f2 = @src.CountingBloomFilter::with_size(4096, 6)
  for i = 0; i < 150; i = i + 1 { f1.insert("c-" + i.to_string()) }
  for i = 100; i < 250; i = i + 1 { f2.insert("d-" + i.to_string()) }
  let shared = ["t-0", "t-1"]
  for s in shared { f1.insert(s); f2.insert(s); f2.insert(s) }

  let u = f1.union(f2)
  for s in shared { assert_true(u.contains(s)) }
  assert_true(f1.is_subset_of(u))
  assert_true(f2.is_subset_of(u))

  let inter = f1.intersection(f2)
  for s in shared { assert_true(inter.contains(s)) }

  let empty = @src.CountingBloomFilter::with_size(4096, 6)
  assert_true(f1.is_disjoint_from(empty))
  assert_true(empty.is_subset_of(f1))
  assert_false(f1.is_subset_of(empty))
}

///|
/// insert_all_if_absent returns the number of newly added keys and skips
/// duplicates and already-present keys.
test "fuzz insert_all_if_absent count" {
  let f = @src.BloomFilter::new(100, 0.01)
  let empty_keys : Array[String] = []
  assert_eq(f.insert_all_if_absent(empty_keys), 0)
  assert_eq(f.insert_all_if_absent(["x", "y", "z"]), 3)
  assert_eq(f.insert_all_if_absent(["x", "y", "w"]), 1)
  assert_eq(f.insert_all_if_absent(["x", "y", "z"]), 0)
  assert_eq(f.count(), 4)

  let g = @src.CountingBloomFilter::new(100, 0.01)
  assert_eq(g.insert_all_if_absent(["m", "n", "m"]), 2)
  assert_eq(g.count(), 2)
  assert_true(g.contains("m"))
  assert_true(g.contains("n"))
}
