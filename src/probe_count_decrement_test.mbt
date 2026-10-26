fn probe_dec_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

test "probe counting count decreases on successful remove" {
  for layout in [(16, 17), (16, 33), (32, 64), (48, 65), (64, 130)] {
    let (slots, hashes) = layout
    for round = 1; round <= 200; round = round + 1 {
      let f = @src.CountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 977 + slots
      for step = 0; step < 2000; step = step + 1 {
        seed = probe_dec_seed(seed)
        let key = seed % 9
        if seed / 13 % 2 == 0 {
          f.insert(key)
        } else {
          let before = f.count()
          if f.remove(key) {
            let after = f.count()
            if before - after != 1 {
              abort("counting remove changed count by " + (before - after).to_string() + " for layout ")
            }
          }
        }
      }
    }
  }
}

test "probe compact counting count decreases on successful remove" {
  for layout in [(16, 17), (16, 33), (32, 64), (48, 65), (64, 130)] {
    let (slots, hashes) = layout
    for round = 1; round <= 200; round = round + 1 {
      let f = @src.CompactCountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 977 + slots
      for step = 0; step < 2000; step = step + 1 {
        seed = probe_dec_seed(seed)
        let key = seed % 9
        if seed / 13 % 2 == 0 {
          f.insert(key)
        } else {
          let before = f.count()
          if f.remove(key) {
            let after = f.count()
            if before - after != 1 {
              abort("compact remove changed count by " + (before - after).to_string() + " for layout ")
            }
          }
        }
      }
    }
  }
}
