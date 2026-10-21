///|
test "cuckoo intersection finds keys stored in the higher candidate bucket" {
  for round = 1; round <= 20; round = round + 1 {
    let left = @src.CuckooFilter::with_size(64, 4)
    let right = @src.CuckooFilter::with_size(64, 4)
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
          ignore(left.remove(key))
          live_left[key] = live_left[key] - 1
        }
      } else if live_right[key] > 0 {
        ignore(right.remove(key))
        live_right[key] = live_right[key] - 1
      }
    }
    let common = left.intersection(right)
    for key = 0; key < 20; key = key + 1 {
      if live_left[key] > 0 && live_right[key] > 0 {
        assert_true(common.contains(key))
      }
    }
  }
}
