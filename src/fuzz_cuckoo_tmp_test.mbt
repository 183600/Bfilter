///|
test "fuzz cuckoo set operations" {
  let key_count = 12
  for round = 1; round <= 300; round = round + 1 {
    let bucket_count = 1 << (round % 4)
    let bucket_size = round % 3 + 1
    let left = @src.CuckooFilter::with_size(bucket_count, bucket_size)
    let right = @src.CuckooFilter::with_size(bucket_count, bucket_size)
    let live_left : Array[Int32] = Array::make(key_count, 0)
    let live_right : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 65537 + 7
    for step = 0; step < 80; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let action = seed / 17 % 5
      if action == 0 {
        if left.insert(key) {
          live_left[key] = live_left[key] + 1
        }
      } else if action == 1 {
        if right.insert(key) {
          live_right[key] = live_right[key] + 1
        }
      } else if action == 2 {
        if live_left[key] > 0 {
          assert_true(left.remove(key))
          live_left[key] = live_left[key] - 1
        }
      } else if action == 3 {
        if live_right[key] > 0 {
          assert_true(right.remove(key))
          live_right[key] = live_right[key] - 1
        }
      } else {
        if live_left[key] > 0 {
          assert_true(left.contains(key))
        }
        if live_right[key] > 0 {
          assert_true(right.contains(key))
        }
      }
    }
    assert_eq(left.count(), live_left.fold(init=0, (a, b) => a + b))
    assert_eq(right.count(), live_right.fold(init=0, (a, b) => a + b))
    let inter = left.intersection(right)
    assert_true(inter.count() <= left.count())
    assert_true(inter.count() <= right.count())
    let restored_inter = @src.CuckooFilter::from_bytes(inter.to_bytes())
    assert_eq(restored_inter.count(), inter.count())
    for key = 0; key < key_count; key = key + 1 {
      if live_left[key] > 0 && live_right[key] > 0 {
        assert_true(inter.contains(key))
        assert_true(restored_inter.contains(key))
      }
      assert_eq(restored_inter.count_of(key), inter.count_of(key))
    }
    assert_true(inter.is_subset_of(left))
    assert_true(inter.is_subset_of(right))
    match left.union(right) {
      Some(combined) => {
      assert_eq(combined.count(), left.count() + right.count())
      let restored = @src.CuckooFilter::from_bytes(combined.to_bytes())
      assert_eq(restored.count(), combined.count())
      for key = 0; key < key_count; key = key + 1 {
        if live_left[key] > 0 || live_right[key] > 0 {
          assert_true(combined.contains(key))
          assert_true(restored.contains(key))
        }
      }
      assert_true(left.is_subset_of(combined))
      assert_true(right.is_subset_of(combined))
      let merged = left.copy()
      // Source and destination share storage only through copies; merge adopts
      // whichever union result it computes.
      assert_true(merged.merge(right))
      assert_eq(merged.count(), combined.count())
      for key = 0; key < key_count; key = key + 1 {
        if live_left[key] > 0 || live_right[key] > 0 {
          assert_true(merged.contains(key))
        }
      }
      }
      None => ()
    }
  }
}
