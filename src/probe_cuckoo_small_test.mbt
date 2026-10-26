///|
fn probe_cuckoo_seed(s : Int32) -> Int32 {
  (s * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "probe small cuckoo set operations" {
  let configs : Array[(Int32, Int32)] = [(1,1),(2,1),(4,1),(1,2),(2,2),(4,2),(2,3),(4,3),(8,4)]
  for cfg in configs {
    let bc = cfg.0
    let bs = cfg.1
    for round = 1; round <= 100; round = round + 1 {
      let left = @src.CuckooFilter::with_size(bc, bs)
      let right = @src.CuckooFilter::with_size(bc, bs)
      let nkeys = 10
      let ll : Array[Int32] = Array::make(nkeys, 0)
      let rl : Array[Int32] = Array::make(nkeys, 0)
      let mut seed = round * 37 + bc * 3 + bs
      for step = 0; step < 50; step = step + 1 {
        seed = probe_cuckoo_seed(seed)
        let k = seed % nkeys
        let act = seed / 31 % 3
        if act == 0 {
          if left.insert(k) { ll[k] = ll[k] + 1 }
        } else if act == 1 {
          if right.insert(k) { rl[k] = rl[k] + 1 }
        } else if seed / 7 % 2 == 0 {
          if ll[k] > 0 && left.remove(k) { ll[k] = ll[k] - 1 }
        } else if rl[k] > 0 && right.remove(k) {
          rl[k] = rl[k] - 1
        }
      }
      for k = 0; k < nkeys; k = k + 1 {
        if ll[k] > 0 {
          assert_true(left.contains(k))
          assert_true(left.count_of(k) >= ll[k])
          assert_true(left.count_of(k) <= ll[k] + rl[k] + 10)
        }
        if rl[k] > 0 {
          assert_true(right.contains(k))
          assert_true(right.count_of(k) >= rl[k])
        }
      }
      let common = left.intersection(right)
      assert_true(common.is_subset_of(left))
      assert_true(common.is_subset_of(right))
      assert_true(common.count() <= left.count().min(right.count()))
      let restored = @src.CuckooFilter::from_bytes(common.to_bytes())
      assert_eq(restored.count(), common.count())
      for k = 0; k < nkeys; k = k + 1 {
        if ll[k] > 0 && rl[k] > 0 {
          assert_true(common.contains(k))
          assert_true(restored.contains(k))
        }
        assert_eq(restored.count_of(k), common.count_of(k))
      }
      match left.union(right) {
        Some(combined) => {
          assert_eq(combined.count(), left.count() + right.count())
          for k = 0; k < nkeys; k = k + 1 {
            if ll[k] > 0 {
              assert_true(combined.contains(k))
              assert_true(left.is_subset_of(combined))
            }
            if rl[k] > 0 {
              assert_true(combined.contains(k))
              assert_true(right.is_subset_of(combined))
            }
          }
          let rr = @src.CuckooFilter::from_bytes(combined.to_bytes())
          assert_eq(rr.count(), combined.count())
          for k = 0; k < nkeys; k = k + 1 {
            if ll[k] > 0 || rl[k] > 0 {
              assert_true(rr.contains(k))
            }
          }
        }
        None => ()
      }
      let lc = left.copy()
      if left.merge(right) {
        assert_eq(left.count(), lc.count() + right.count())
        assert_true(lc.is_subset_of(left))
        assert_true(right.is_subset_of(left))
      } else {
        assert_eq(left.count(), lc.count())
      }
    }
  }
}
