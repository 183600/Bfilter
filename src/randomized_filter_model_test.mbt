///|
test "randomized counting operations match a live-key model" {
  for round = 1; round <= 100; round = round + 1 {
    let f = @src.CountingBloomFilter::with_size(32, 8)
    let live : Array[Int32] = Array::make(12, 0)
    let mut seed = round
    for step = 0; step < 1000; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 12
      let action = seed / 31 % 4
      if action == 0 {
        f.insert(key)
        live[key] = live[key] + 1
      } else if action == 1 {
        if live[key] > 0 {
          assert_true(f.remove(key))
          live[key] = live[key] - 1
        }
      } else if action == 2 {
        if live[key] > 0 {
          assert_true(f.contains(key))
          assert_true(f.count_of(key) >= live[key])
        }
      } else {
        let copy = f.copy()
        let bytes = f.to_bytes()
        let restored = @src.CountingBloomFilter::from_bytes(bytes)
        for k = 0; k < 12; k = k + 1 {
          if live[k] > 0 {
            assert_true(restored.contains(k))
            assert_true(copy.contains(k))
          }
          assert_eq(restored.count_of(k), f.count_of(k))
        }
        assert_eq(restored.count(), f.count())
      }
    }
    let mut total = 0
    for key = 0; key < 12; key = key + 1 {
      total = total + live[key]
      if live[key] > 0 {
        assert_true(f.contains(key))
      }
    }
    assert_eq(f.count(), total)
  }
}

///|
test "randomized cuckoo operations match a live-key model" {
  for round = 1; round <= 100; round = round + 1 {
    let f = @src.CuckooFilter::with_size(64, 4)
    let live : Array[Int32] = Array::make(12, 0)
    let mut seed = round
    for step = 0; step < 1000; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 12
      let action = seed / 31 % 4
      if action == 0 {
        if f.insert(key) {
          live[key] = live[key] + 1
        }
      } else if action == 1 {
        if live[key] > 0 {
          assert_true(f.remove(key))
          live[key] = live[key] - 1
        }
      } else if action == 2 {
        if live[key] > 0 {
          assert_true(f.contains(key))
          assert_true(f.count_of(key) >= live[key])
        }
      } else {
        let copy = f.copy()
        let restored = @src.CuckooFilter::from_bytes(f.to_bytes())
        for k = 0; k < 12; k = k + 1 {
          if live[k] > 0 {
            assert_true(restored.contains(k))
            assert_true(copy.contains(k))
          }
          assert_eq(restored.count_of(k), f.count_of(k))
        }
        assert_eq(restored.count(), f.count())
      }
    }
    let mut total = 0
    for key = 0; key < 12; key = key + 1 {
      total = total + live[key]
      if live[key] > 0 {
        assert_true(f.contains(key))
      }
    }
    assert_eq(f.count(), total)
  }
}

///|
test "randomized cuckoo unions and merges preserve live keys" {
  for round = 1; round <= 100; round = round + 1 {
    let left = @src.CuckooFilter::with_size(32, 4)
    let right = @src.CuckooFilter::with_size(32, 4)
    let live_left : Array[Int32] = Array::make(20, 0)
    let live_right : Array[Int32] = Array::make(20, 0)
    let mut seed = round
    for step = 0; step < 300; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 20
      let which = seed / 31 % 4
      if which == 0 {
        if left.insert(key) {
          live_left[key] = live_left[key] + 1
        }
      } else if which == 1 {
        if right.insert(key) {
          live_right[key] = live_right[key] + 1
        }
      } else if which == 2 {
        if live_left[key] > 0 {
          assert_true(left.remove(key))
          live_left[key] = live_left[key] - 1
        }
      } else if live_right[key] > 0 {
        assert_true(right.remove(key))
        live_right[key] = live_right[key] - 1
      }
    }
    match left.union(right) {
      Some(combined) => {
        for key = 0; key < 20; key = key + 1 {
          if live_left[key] > 0 || live_right[key] > 0 {
            assert_true(combined.contains(key))
          }
        }
        assert_true(left.is_subset_of(combined))
        assert_true(right.is_subset_of(combined))
        assert_eq(combined.count(), left.count() + right.count())
        let restored = @src.CuckooFilter::from_bytes(combined.to_bytes())
        assert_eq(restored.count(), combined.count())
        for key = 0; key < 20; key = key + 1 {
          if live_left[key] > 0 || live_right[key] > 0 {
            assert_true(restored.contains(key))
          }
        }
      }
      None =>
        for key = 0; key < 20; key = key + 1 {
          if live_left[key] > 0 {
            assert_true(left.contains(key))
          }
          if live_right[key] > 0 {
            assert_true(right.contains(key))
          }
        }
    }
    let left_copy = left.copy()
    if left.merge(right) {
      assert_eq(left.count(), left_copy.count() + right.count())
      assert_true(left_copy.is_subset_of(left))
      assert_true(right.is_subset_of(left))
    } else {
      assert_eq(left.count(), left_copy.count())
    }
  }
}
