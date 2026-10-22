///|
test "randomized scalable bloom filters preserve membership across set operations" {
  for round = 1; round <= 40; round = round + 1 {
    let left = @src.ScalableBloomFilter::new(2, 0.01)
    let right = @src.ScalableBloomFilter::new(2, 0.01)
    let left_live : Array[Bool] = Array::make(64, false)
    let right_live : Array[Bool] = Array::make(64, false)
    let mut seed = round * 3571 + 7
    for step = 0; step < 200; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 64
      let action = seed / 31 % 4
      if action == 0 {
        left.insert(key)
        left_live[key] = true
      } else if action == 1 {
        right.insert(key)
        right_live[key] = true
      } else if action == 2 {
        let copy = left.copy()
        copy.insert(1000 + key)
        assert_true(copy.contains(1000 + key))
        for k = 0; k < 64; k = k + 1 {
          if left_live[k] {
            assert_true(copy.contains(k))
          }
        }
      } else {
        let restored = @src.ScalableBloomFilter::from_bytes(left.to_bytes())
        assert_eq(restored.count(), left.count())
        assert_eq(restored.slice_count(), left.slice_count())
        for k = 0; k < 64; k = k + 1 {
          if left_live[k] {
            assert_true(restored.contains(k))
          }
        }
      }
    }
    for k = 0; k < 64; k = k + 1 {
      if left_live[k] {
        assert_true(left.contains(k))
      }
      if right_live[k] {
        assert_true(right.contains(k))
      }
    }
    let combined = left.union(right)
    assert_eq(combined.count(), left.count() + right.count())
    assert_true(left.is_subset_of(combined))
    assert_true(right.is_subset_of(combined))
    for k = 0; k < 64; k = k + 1 {
      if left_live[k] || right_live[k] {
        assert_true(combined.contains(k))
      }
    }
    let restored = @src.ScalableBloomFilter::from_bytes(combined.to_bytes())
    assert_true(left.is_subset_of(restored))
    assert_true(right.is_subset_of(restored))
    let common = left.intersection(right)
    assert_eq(common.count(), left.count().min(right.count()))
    assert_true(common.is_subset_of(left))
    assert_true(common.is_subset_of(right))
    ignore(@src.ScalableBloomFilter::from_bytes(common.to_bytes()))
    let merged = left.copy()
    merged.merge(right)
    assert_true(left.is_subset_of(merged))
    assert_true(right.is_subset_of(merged))
    let empty = @src.ScalableBloomFilter::new(2, 0.01)
    assert_true(empty.is_disjoint_from(left))
    assert_true(left.is_disjoint_from(empty))
  }
}
