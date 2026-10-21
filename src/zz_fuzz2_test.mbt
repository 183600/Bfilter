///|
test "zz fuzz cuckoo operations preserve live keys across layouts" {
  let layouts : Array[(Int32, Int32)] = [
    (1, 1), (2, 2), (4, 1), (8, 2), (16, 4), (32, 3), (64, 8),
  ]
  for layout in layouts {
    let (bucket_count, bucket_size) = layout
    for round = 1; round <= 20; round = round + 1 {
      let filter = @src.CuckooFilter::with_size(bucket_count, bucket_size)
      let key_count = bucket_count * bucket_size + 8
      let live : Array[Int32] = Array::make(key_count, 0)
      let mut seed = round * 7919 + 13
      for step = 0; step < 2000; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % key_count
        let action = seed / 31 % 5
        if action == 0 {
          if filter.insert(key) {
            live[key] = live[key] + 1
          }
        } else if action == 1 {
          if live[key] > 0 {
            assert_true(filter.remove(key))
            live[key] = live[key] - 1
          }
        } else if action == 2 {
          if live[key] > 0 {
            assert_true(filter.contains(key))
          }
        } else if action == 3 {
          let restored = @src.CuckooFilter::from_bytes(filter.to_bytes())
          assert_eq(restored.count(), filter.count())
          for k = 0; k < key_count; k = k + 1 {
            if live[k] > 0 {
              assert_true(restored.contains(k))
            }
          }
        } else {
          let copy = filter.copy()
          assert_eq(copy.count(), filter.count())
          for k = 0; k < key_count; k = k + 1 {
            if live[k] > 0 {
              assert_true(copy.contains(k))
            }
          }
        }
      }
      let mut total = 0
      for k = 0; k < key_count; k = k + 1 {
        total = total + live[k]
        if live[k] > 0 {
          assert_true(filter.contains(k))
        }
      }
      assert_eq(filter.count(), total)
    }
  }
}

///|
test "zz fuzz cuckoo set ops preserve live keys" {
  let layouts : Array[(Int32, Int32)] = [
    (4, 1), (8, 2), (16, 4), (32, 3), (64, 4),
  ]
  for layout in layouts {
    let (bucket_count, bucket_size) = layout
    for round = 1; round <= 40; round = round + 1 {
      let left = @src.CuckooFilter::with_size(bucket_count, bucket_size)
      let right = @src.CuckooFilter::with_size(bucket_count, bucket_size)
      let key_count = bucket_count * bucket_size / 2 + 6
      let ll : Array[Int32] = Array::make(key_count, 0)
      let rr : Array[Int32] = Array::make(key_count, 0)
      let mut seed = round * 3571 + 7
      for step = 0; step < 400; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % key_count
        let action = seed / 31 % 4
        if action == 0 {
          if left.insert(key) {
            ll[key] = ll[key] + 1
          }
        } else if action == 1 {
          if right.insert(key) {
            rr[key] = rr[key] + 1
          }
        } else if action == 2 {
          if ll[key] > 0 {
            assert_true(left.remove(key))
            ll[key] = ll[key] - 1
          }
        } else if rr[key] > 0 {
          assert_true(right.remove(key))
          rr[key] = rr[key] - 1
        }
      }
      let left_before = left.copy()
      let right_before = right.copy()
      match left.union(right) {
        Some(combined) => {
          assert_eq(combined.count(), left.count() + right.count())
          assert_true(left.is_subset_of(combined))
          assert_true(right.is_subset_of(combined))
          for k = 0; k < key_count; k = k + 1 {
            if ll[k] > 0 || rr[k] > 0 {
              assert_true(combined.contains(k))
            }
          }
          let restored = @src.CuckooFilter::from_bytes(combined.to_bytes())
          assert_eq(restored.count(), combined.count())
          for k = 0; k < key_count; k = k + 1 {
            if ll[k] > 0 || rr[k] > 0 {
              assert_true(restored.contains(k))
            }
          }
        }
        None => ()
      }
      let common = left.intersection(right)
      assert_true(common.is_subset_of(left))
      assert_true(common.is_subset_of(right))
      assert_true(common.count() <= left.count().min(right.count()))
      for k = 0; k < key_count; k = k + 1 {
        if ll[k] > 0 && rr[k] > 0 {
          assert_true(common.contains(k))
        }
      }
      let merge_target = left.copy()
      if merge_target.merge(right) {
        assert_eq(merge_target.count(), left.count() + right.count())
        assert_true(left.is_subset_of(merge_target))
        assert_true(right.is_subset_of(merge_target))
      } else {
        assert_eq(merge_target.count(), left.count())
        assert_true(left_before.is_subset_of(merge_target))
      }
      assert_eq(left.to_bytes(), left_before.to_bytes())
      assert_eq(right.to_bytes(), right_before.to_bytes())
    }
  }
}
