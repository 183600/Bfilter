///|
test "tmp probe cuckoo union subset randomized" {
  let layouts : Array[(Int32, Int32)] = [
    (1, 1), (2, 1), (2, 2), (4, 1), (4, 3), (8, 2), (16, 4), (32, 3),
  ]
  for layout in layouts {
    let (bc, bs) = layout
    for seed0 = 1; seed0 <= 25; seed0 = seed0 + 1 {
      let left = @src.CuckooFilter::with_size(bc, bs)
      let right = @src.CuckooFilter::with_size(bc, bs)
      let mut seed = seed0
      let live_left : Array[Int] = Array::make(20, 0)
      let live_right : Array[Int] = Array::make(20, 0)
      for step = 0; step < 30; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 20
        let which = seed / 31 % 3
        if which == 0 {
          if left.insert(key) { live_left[key] = live_left[key] + 1 }
        } else if which == 1 {
          if right.insert(key) { live_right[key] = live_right[key] + 1 }
        } else {
          if live_left[key] > 0 {
            assert_true(left.remove(key))
            live_left[key] = live_left[key] - 1
          }
          if live_right[key] > 0 {
            assert_true(right.remove(key))
            live_right[key] = live_right[key] - 1
          }
        }
      }
      for key = 0; key < 20; key = key + 1 {
        if live_left[key] > 0 { assert_true(left.contains(key)) }
        if live_right[key] > 0 { assert_true(right.contains(key)) }
      }
      match left.union(right) {
        Some(c) => {
          for key = 0; key < 20; key = key + 1 {
            if live_left[key] > 0 || live_right[key] > 0 {
              assert_true(c.contains(key))
            }
          }
          assert_true(left.is_subset_of(c))
          assert_true(right.is_subset_of(c))
          assert_eq(c.count(), left.count() + right.count())
        }
        None => ()
      }
    }
  }
}

///|
test "tmp probe counting randomized against naive" {
  for round = 1; round <= 20; round = round + 1 {
    let f = @src.CountingBloomFilter::with_size(128, 4)
    let live : Array[Int] = Array::make(16, 0)
    let mut seed = round
    for step = 0; step < 500; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 16
      let action = seed / 31 % 3
      if action == 0 {
        f.insert(key)
        live[key] = live[key] + 1
      } else if action == 1 {
        if live[key] > 0 {
          assert_true(f.remove(key))
          live[key] = live[key] - 1
        }
      } else {
        if live[key] > 0 {
          assert_true(f.contains(key))
        }
      }
    }
    let mut total = 0
    for key = 0; key < 16; key = key + 1 {
      total = total + live[key]
    }
    assert_eq(f.count(), total)
  }
}
