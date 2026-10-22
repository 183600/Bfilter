///|
test "randomized scalable counting set operations preserve keys and serialization" {
  for round = 1; round <= 40; round = round + 1 {
    let key_count = 24
    let left = @src.ScalableCountingBloomFilter::new(3, 0.01)
    let right = @src.ScalableCountingBloomFilter::new(3, 0.01)
    let live_left : Array[Int32] = Array::make(key_count, 0)
    let live_right : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 7919 + 17
    for step = 0; step < 300; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let which = seed / 31 % 5
      if which == 0 {
        left.insert(key); live_left[key] = live_left[key] + 1
      } else if which == 1 {
        right.insert(key); live_right[key] = live_right[key] + 1
      } else if which == 2 {
        if live_left[key] > 0 {
          assert_true(left.remove(key)); live_left[key] = live_left[key] - 1
        }
      } else if which == 3 {
        if live_right[key] > 0 {
          assert_true(right.remove(key)); live_right[key] = live_right[key] - 1
        }
      } else if seed % 3 == 0 {
        let common = left.intersection(right)
        for k = 0; k < key_count; k = k + 1 {
          if live_left[k] > 0 && live_right[k] > 0 {
            assert_true(common.contains(k))
            assert_eq(common.count_of(k), live_left[k].min(live_right[k]))
          }
        }
        assert_true(common.is_subset_of(left))
        assert_true(common.is_subset_of(right))
        let restored = @src.ScalableCountingBloomFilter::from_bytes(common.to_bytes())
        assert_eq(restored.to_bytes(), common.to_bytes())
      }
    }
    let combined = left.union(right)
    for k = 0; k < key_count; k = k + 1 {
      if live_left[k] > 0 || live_right[k] > 0 {
        assert_true(combined.contains(k))
      }
      if live_left[k] > 0 { assert_true(left.is_subset_of(combined)) }
    }
    assert_true(left.is_subset_of(combined))
    assert_true(right.is_subset_of(combined))
    for k = 0; k < key_count; k = k + 1 {
      assert_true(combined.count_of(k) >= left.count_of(k).max(right.count_of(k)))
      assert_true(combined.count_of(k) <= left.count_of(k) + right.count_of(k))
    }
    let restored = @src.ScalableCountingBloomFilter::from_bytes(combined.to_bytes())
    assert_eq(restored.to_bytes(), combined.to_bytes())
    let merged = left.copy()
    merged.merge(right)
    assert_eq(merged.to_bytes(), combined.to_bytes())
  }
}

///|
test "randomized scalable bloom merges preserve keys and serialization" {
  for round = 1; round <= 40; round = round + 1 {
    let key_count = 24
    let left = @src.ScalableBloomFilter::new(3, 0.01)
    let right = @src.ScalableBloomFilter::new(3, 0.01)
    let live_left : Array[Bool] = Array::make(key_count, false)
    let live_right : Array[Bool] = Array::make(key_count, false)
    let mut seed = round * 3571 + 3
    for step = 0; step < 300; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      if seed % 2 == 0 { left.insert(key); live_left[key] = true }
      else { right.insert(key); live_right[key] = true }
    }
    let combined = left.union(right)
    assert_true(left.is_subset_of(combined))
    assert_true(right.is_subset_of(combined))
    for k = 0; k < key_count; k = k + 1 {
      if live_left[k] || live_right[k] { assert_true(combined.contains(k)) }
    }
    let restored = @src.ScalableBloomFilter::from_bytes(combined.to_bytes())
    assert_eq(restored.to_bytes(), combined.to_bytes())
    let merged = left.copy()
    merged.merge(right)
    assert_eq(merged.to_bytes(), combined.to_bytes())
  }
}

///|
test "randomized cuckoo intersections and unions preserve live keys" {
  for round = 1; round <= 60; round = round + 1 {
    let layouts : Array[(Int32, Int32)] = [(1, 1), (2, 2), (4, 4), (8, 8), (16, 3)]
    let layout = layouts[round % layouts.length()]
    let (bc, bs) = layout
    let key_count = bc * bs + 10
    let left = @src.CuckooFilter::with_size(bc, bs)
    let right = @src.CuckooFilter::with_size(bc, bs)
    let live_left : Array[Int32] = Array::make(key_count, 0)
    let live_right : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 2027 + 11
    for step = 0; step < 300; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let which = seed / 31 % 5
      if which == 0 { if left.insert(key) { live_left[key] = live_left[key] + 1 } }
      else if which == 1 { if right.insert(key) { live_right[key] = live_right[key] + 1 } }
      else if which == 2 && live_left[key] > 0 {
        assert_true(left.remove(key)); live_left[key] = live_left[key] - 1
      } else if which == 3 && live_right[key] > 0 {
        assert_true(right.remove(key)); live_right[key] = live_right[key] - 1
      } else if which == 4 {
        let common = left.intersection(right)
        for k = 0; k < key_count; k = k + 1 {
          if live_left[k] > 0 && live_right[k] > 0 { assert_true(common.contains(k)) }
        }
        assert_true(common.is_subset_of(left))
        assert_true(common.is_subset_of(right))
        let restored = @src.CuckooFilter::from_bytes(common.to_bytes())
        assert_eq(restored.to_bytes(), common.to_bytes())
      }
    }
    let common = left.intersection(right)
    for k = 0; k < key_count; k = k + 1 {
      if live_left[k] > 0 && live_right[k] > 0 { assert_true(common.contains(k)) }
    }
    assert_true(common.is_subset_of(left))
    assert_true(common.is_subset_of(right))
    match left.union(right) {
      Some(combined) => {
        assert_eq(combined.count(), left.count() + right.count())
        assert_true(left.is_subset_of(combined))
        assert_true(right.is_subset_of(combined))
        for k = 0; k < key_count; k = k + 1 {
          if live_left[k] > 0 || live_right[k] > 0 { assert_true(combined.contains(k)) }
        }
        let restored = @src.CuckooFilter::from_bytes(combined.to_bytes())
        assert_eq(restored.to_bytes(), combined.to_bytes())
      }
      None => ()
    }
  }
}
