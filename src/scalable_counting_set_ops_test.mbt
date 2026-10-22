///|
test "scalable counting filters merge keys from both inputs" {
  let left = @src.ScalableCountingBloomFilter::new(4, 0.01)
  let right = @src.ScalableCountingBloomFilter::new(4, 0.01)
  for i = 0; i < 12; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 6; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  left.merge(right)
  assert_eq(left.count(), 18)
  for i = 0; i < 12; i = i + 1 {
    assert_true(left.contains("left-" + i.to_string()))
    assert_eq(left.count_of("left-" + i.to_string()), 1)
  }
  for i = 0; i < 6; i = i + 1 {
    assert_true(left.contains("right-" + i.to_string()))
    assert_eq(left.count_of("right-" + i.to_string()), 1)
  }
  assert_eq(right.count(), 6)
  left.insert("after-merge")
  assert_eq(left.count(), 19)
  assert_eq(left.count_of("after-merge"), 1)
}

///|
test "scalable counting filter union leaves inputs unchanged" {
  let left = @src.ScalableCountingBloomFilter::new(4, 0.01)
  let right = @src.ScalableCountingBloomFilter::new(4, 0.01)
  left.insert("shared")
  left.insert("shared")
  left.insert("left-only")
  right.insert("shared")
  right.insert("right-only")
  let combined = left.union(right)
  assert_true(combined.count() <= left.count() + right.count())
  assert_eq(combined.count_of("shared"), 2)
  let serialized = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_eq(serialized.count(), combined.count())
  assert_eq(serialized.count_of("shared"), 2)
  assert_true(combined.contains("left-only"))
  assert_true(combined.contains("right-only"))
  assert_true(combined.remove("shared"))
  assert_eq(combined.count_of("shared"), 1)
  assert_true(combined.remove("shared"))
  assert_eq(combined.count_of("shared"), 0)
  assert_eq(left.count_of("shared"), 2)
  assert_eq(right.count_of("shared"), 1)
  assert_false(left.contains("right-only"))
  assert_false(right.contains("left-only"))
}

///|
test "scalable counting union combines keys stored in different slices" {
  let left = @src.ScalableCountingBloomFilter::new(4, 0.001)
  let right = @src.ScalableCountingBloomFilter::new(4, 0.001)
  left.insert("shared")
  for i = 0; i < 20; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 20; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  right.insert("shared")
  assert_true(left.slice_count() > 1)
  assert_true(right.slice_count() > 1)
  let combined = left.union(right)
  assert_eq(combined.count_of("shared"), 2)
  assert_true(combined.remove("shared"))
  assert_eq(combined.count_of("shared"), 1)
  assert_true(combined.remove("shared"))
  assert_eq(combined.count_of("shared"), 0)
  assert_false(combined.remove("shared"))
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_eq(restored.count(), combined.count())
  assert_eq(restored.count_of("shared"), 0)
}

///|
test "scalable counting filter subset follows slice layouts" {
  let base = @src.ScalableCountingBloomFilter::new(4, 0.01)
  for i = 0; i < 15; i = i + 1 {
    base.insert(i)
  }
  let superset = base.copy()
  assert_true(base.is_subset_of(superset))
  assert_true(base.is_subset_of(base))
  superset.insert("extra")
  assert_true(base.is_subset_of(superset))
  assert_false(superset.is_subset_of(base))
  let short = @src.ScalableCountingBloomFilter::new(4, 0.01)
  short.insert("kept")
  assert_false(base.is_subset_of(short))
}

///|
test "scalable counting subset follows tracked keys across slices" {
  let left = @src.ScalableCountingBloomFilter::new(1, 0.01)
  left.insert("shared")
  for i = 0; i < 20; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  let right = @src.ScalableCountingBloomFilter::new(1, 0.01)
  for i = 0; i < 20; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  right.insert("shared")
  assert_true(left.slice_count() > 1)
  assert_true(right.slice_count() > 1)

  let combined = left.union(right)
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  assert_true(combined.contains("shared"))
  assert_eq(combined.count_of("shared"), 2)

  let common = left.intersection(right)
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
  assert_eq(common.count_of("shared"), 1)

  let merged = left.copy()
  merged.merge(right)
  assert_true(left.is_subset_of(merged))
  assert_true(right.is_subset_of(merged))
  assert_eq(merged.count_of("shared"), 2)

  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_true(left.is_subset_of(restored))
  assert_true(right.is_subset_of(restored))
  assert_eq(restored.count_of("shared"), 2)
}

///|
test "scalable counting filters detect definite disjointness" {
  let left = @src.ScalableCountingBloomFilter::new(1 << 20, 0.001)
  let right = @src.ScalableCountingBloomFilter::new(1 << 20, 0.001)
  assert_true(left.is_disjoint_from(right))
  for i = 0; i < 5; i = i + 1 {
    left.insert("left-" + i.to_string())
    right.insert("right-" + i.to_string())
  }
  assert_true(left.is_disjoint_from(right))
  right.insert("left-3")
  assert_false(left.is_disjoint_from(right))
  assert_false(right.is_disjoint_from(left))
  assert_true(right.remove("left-3"))
  assert_true(left.is_disjoint_from(right))
}

///|
test "scalable counting disjointness handles extra slices" {
  let short = @src.ScalableCountingBloomFilter::new(2, 0.01)
  let long = @src.ScalableCountingBloomFilter::new(2, 0.01)
  short.insert("early")
  for i = 0; i < 20; i = i + 1 {
    long.insert(i)
  }
  assert_true(long.slice_count() > short.slice_count())
  assert_false(long.is_disjoint_from(short))
  long.clear()
  assert_true(long.is_disjoint_from(short))
}

///|
test "panic scalable counting set operations reject different policies" {
  let left = @src.ScalableCountingBloomFilter::new(4, 0.01)
  let right_capacity = @src.ScalableCountingBloomFilter::new(8, 0.01)
  left.merge(right_capacity)
  let right_rate = @src.ScalableCountingBloomFilter::new(4, 0.001)
  left.union(right_rate) |> ignore
  left.is_subset_of(right_capacity) |> ignore
  left.is_disjoint_from(right_rate) |> ignore
}

///|
test "concurrent scalable counting filter supports set operations" {
  let left = @src.ConcurrentScalableCountingBloomFilter::new(4, 0.01)
  let right = @src.ScalableCountingBloomFilter::new(4, 0.01)
  for i = 0; i < 10; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 6; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  let combined = left.union(right)
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  assert_true(
    left.is_disjoint_from(@src.ScalableCountingBloomFilter::new(4, 0.01)),
  )
  left.merge(right)
  assert_eq(left.count(), 16)
  for i = 0; i < 6; i = i + 1 {
    assert_true(left.contains("right-" + i.to_string()))
  }
  assert_eq(left.snapshot().count_of("right-0"), 1)
}

///|
test "scalable counting union keeps every tracked key removable" {
  let left = @src.ScalableCountingBloomFilter::new(3, 0.01)
  let right = @src.ScalableCountingBloomFilter::new(3, 0.01)
  let key_count = 12
  let left_live : Array[Int32] = Array::make(key_count, 0)
  let right_live : Array[Int32] = Array::make(key_count, 0)
  let mut seed = 614
  for step = 0; step < 200; step = step + 1 {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    let key = seed % key_count
    if seed / 31 % 2 == 0 {
      left.insert(key)
      left_live[key] = left_live[key] + 1
    } else {
      right.insert(key)
      right_live[key] = right_live[key] + 1
    }
  }
  let combined = left.union(right)
  for key = 0; key < key_count; key = key + 1 {
    let occurrences = combined.count_of(key)
    for i = 0; i < occurrences; i = i + 1 {
      assert_true(combined.remove(key))
    }
    assert_eq(combined.count_of(key), 0)
    assert_false(combined.contains(key))
  }
  assert_eq(combined.count(), 0)
  assert_eq(combined.tracked_key_count(), 0)
  assert_eq(left.count_of(1), left_live[1])
  assert_eq(right.count_of(1), right_live[1])
  let restored = @src.ScalableCountingBloomFilter::from_bytes(
    combined.to_bytes(),
  )
  assert_eq(restored.count(), combined.count())
  assert_eq(restored.tracked_key_count(), 0)
}

///|
test "scalable counting chained merges keep every key removable" {
  for round = 1; round <= 3; round = round + 1 {
    let key_count = 40
    let mut combined = @src.ScalableCountingBloomFilter::new(4, 0.01)
    let seen : Array[Bool] = Array::make(key_count, false)
    let mut seed = round * 2027 + 5
    for part = 0; part < 5; part = part + 1 {
      let partner = @src.ScalableCountingBloomFilter::new(4, 0.01)
      for step = 0; step < 120; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % key_count
        partner.insert(key)
        seen[key] = true
      }
      if part % 2 == 0 {
        combined.merge(partner)
      } else {
        let union = combined.union(partner)
        combined.clear()
        combined.merge(union)
      }
      combined = @src.ScalableCountingBloomFilter::from_bytes(
        combined.to_bytes(),
      )
      for key = 0; key < key_count; key = key + 1 {
        if seen[key] {
          assert_true(combined.contains(key))
        }
      }
    }
    for key = 0; key < key_count; key = key + 1 {
      let occurrences = combined.count_of(key)
      for i = 0; i < occurrences; i = i + 1 {
        assert_true(combined.remove(key))
      }
      assert_eq(combined.count_of(key), 0)
    }
    assert_eq(combined.count(), 0)
    assert_eq(combined.tracked_key_count(), 0)
  }
}

///|
test "scalable counting remove follows a merged key to its other slice" {
  let left = @src.ScalableCountingBloomFilter::new(4, 0.000001)
  let right = @src.ScalableCountingBloomFilter::new(4, 0.000001)
  left.insert("shared")
  for i = 0; i < 20; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 20; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  right.insert("shared")
  let combined = left.union(right)
  assert_eq(combined.count_of("shared"), 2)
  assert_true(combined.remove("shared"))
  assert_eq(combined.count_of("shared"), 1)
  assert_true(combined.remove("shared"))
  assert_eq(combined.count_of("shared"), 0)
  assert_false(combined.contains("shared"))
  assert_false(combined.remove("shared"))
  assert_eq(combined.count(), left.count() + right.count() - 2)
}
