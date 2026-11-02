///|
test "compact counting filter union contains keys from both inputs" {
  let left = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
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
test "compact counting filter union keeps the larger multiplicity" {
  let left = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
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
test "compact counting filter intersection keeps keys present in both inputs" {
  let left = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
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
test "compact counting filter subset compares counters" {
  let once = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let twice = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let keys = ["alpha", "beta", "gamma"]
  once.insert_all(keys)
  twice.insert_all(keys)
  twice.insert_all(keys)
  assert_true(once.is_subset_of(twice))
  assert_false(twice.is_subset_of(once))
  let empty = @src.CompactCountingBloomFilter::with_size(8192, 4)
  assert_true(empty.is_subset_of(once))
  assert_true(once.is_subset_of(once))
}

///|
test "panic compact counting filter union rejects incompatible sizes" {
  let left = @src.CompactCountingBloomFilter::with_size(16, 2)
  let right = @src.CompactCountingBloomFilter::with_size(32, 2)
  left.union(right) |> ignore
}

///|
test "panic compact counting filter intersection rejects incompatible hash counts" {
  let left = @src.CompactCountingBloomFilter::with_size(16, 2)
  let right = @src.CompactCountingBloomFilter::with_size(16, 3)
  left.intersection(right) |> ignore
}

///|
test "panic compact counting filter subset rejects incompatible sizes" {
  let left = @src.CompactCountingBloomFilter::with_size(16, 2)
  let right = @src.CompactCountingBloomFilter::with_size(32, 2)
  left.is_subset_of(right) |> ignore
}

///|
test "compact counting filter is_disjoint_from detects no overlap" {
  let left = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let right = @src.CompactCountingBloomFilter::with_size(8192, 4)
  assert_true(left.is_disjoint_from(right))

  let with_overlap = @src.CompactCountingBloomFilter::with_size(8192, 4)
  left.insert("shared")
  with_overlap.insert("shared")
  assert_false(left.is_disjoint_from(with_overlap))
}

///|
test "compact counting filter set operations with serialization round-trip" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1),
    (16, 4),
    (16, 20),
    (48, 20),
    (16, 300),
    (48, 720),
    (256, 2),
  ]
  for layout in layouts {
    let (slots, k) = layout
    for round = 1; round <= 20; round = round + 1 {
      let left = @src.CompactCountingBloomFilter::with_size(slots, k)
      let right = @src.CompactCountingBloomFilter::with_size(slots, k)
      let mut seed = round * 131 + 17
      for step = 0; step < 100; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 20
        let action = seed / 31 % 3
        if action == 0 {
          left.insert(key)
        } else if action == 1 {
          right.insert(key)
        } else {
          let c = left.union(right)
          let restored = @src.CompactCountingBloomFilter::from_bytes(
            c.to_bytes(),
          )
          assert_eq(restored.count(), c.count())
        }
      }
      let u = left.union(right)
      assert_eq(
        @src.CompactCountingBloomFilter::from_bytes(u.to_bytes()).count(),
        u.count(),
      )
      let i = left.intersection(right)
      assert_eq(
        @src.CompactCountingBloomFilter::from_bytes(i.to_bytes()).count(),
        i.count(),
      )
      let m = left.copy()
      m.merge(right)
      assert_eq(
        @src.CompactCountingBloomFilter::from_bytes(m.to_bytes()).count(),
        m.count(),
      )
    }
  }
}

///|
test "compact counting filter empty set operations" {
  let empty = @src.CompactCountingBloomFilter::with_size(8192, 4)
  let filled = @src.CompactCountingBloomFilter::with_size(8192, 4)
  filled.insert("key")

  assert_true(empty.is_subset_of(filled))
  assert_true(filled.is_disjoint_from(empty))
  assert_true(empty.is_disjoint_from(filled))

  let union_result = empty.union(filled)
  assert_eq(union_result.count(), 1)
  assert_true(union_result.contains("key"))

  let intersection_result = filled.intersection(empty)
  assert_true(intersection_result.is_empty())
  assert_eq(intersection_result.count(), 0)

  let merged = empty.copy()
  merged.merge(filled)
  assert_eq(merged.count(), 1)
  assert_true(merged.contains("key"))
}