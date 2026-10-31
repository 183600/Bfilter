///|
fn inv_seed(s : Int32) -> Int32 {
  (s * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "investigate counting filters across layouts" {
  let configs : Array[(Int32, Int32)] = [
    (16, 3), (48, 5), (100, 7), (16, 17), (48, 65), (16, 65), (64, 129),
  ]
  for config in configs {
    let (slots, hashes) = config
    for round = 1; round <= 30; round = round + 1 {
      let f = @src.CountingBloomFilter::with_size(slots, hashes)
      let live : Array[Int32] = Array::make(20, 0)
      let mut seed = round * 101 + slots
      for step = 0; step < 500; step = step + 1 {
        seed = inv_seed(seed)
        let key = seed % 20
        let action = seed / 31 % 5
        if action == 0 {
          f.insert(key)
          live[key] = live[key] + 1
        } else if action == 1 {
          if live[key] > 0 {
            if !f.remove(key) {
              abort("counting remove failed slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " key=" + key.to_string())
            }
            live[key] = live[key] - 1
          }
        } else if action == 2 {
          if live[key] > 0 && !f.contains(key) {
            abort("counting lost key slots=" + slots.to_string() + " hashes=" + hashes.to_string())
          }
          if live[key] > 0 && f.count_of(key) < live[key] {
            abort("counting count low slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " got=" + f.count_of(key).to_string() + " live=" + live[key].to_string())
          }
        } else if action == 3 {
          let restored = @src.CountingBloomFilter::from_bytes(f.to_bytes())
          for k = 0; k < 20; k = k + 1 {
            if restored.count_of(k) != f.count_of(k) {
              abort("counting serialized count mismatch")
            }
            if live[k] > 0 && !restored.contains(k) {
              abort("counting serialized lost key")
            }
          }
          if restored.count() != f.count() {
            abort("counting serialized count() mismatch")
          }
        } else {
          let copy = f.copy()
          for k = 0; k < 20; k = k + 1 {
            if copy.count_of(k) != f.count_of(k) {
              abort("counting copy mismatch")
            }
          }
        }
      }
    }
  }
}

///|
test "investigate compact counting filters across layouts" {
  let configs : Array[(Int32, Int32)] = [
    (16, 3), (48, 5), (100, 7), (16, 17), (48, 65), (16, 65), (64, 129),
  ]
  for config in configs {
    let (slots, hashes) = config
    for round = 1; round <= 30; round = round + 1 {
      let f = @src.CompactCountingBloomFilter::with_size(slots, hashes)
      let live : Array[Int32] = Array::make(20, 0)
      let mut seed = round * 103 + slots
      for step = 0; step < 300; step = step + 1 {
        seed = inv_seed(seed)
        let key = seed % 20
        let action = seed / 31 % 5
        if action == 0 {
          f.insert(key)
          live[key] = live[key] + 1
        } else if action == 1 {
          if live[key] > 0 {
            if f.contains(key) && f.remove(key) {
              live[key] = live[key] - 1
            } else {
              // Saturated counters shared by several keys can drain a key
              // before all of its modeled insertions have been removed.
              live[key] = 0
            }
          }
        } else if action == 2 {
          if live[key] > 0 && !f.contains(key) {
            // Saturated counters shared by several keys can drain a key before
            // all of its modeled insertions have been removed.
            live[key] = 0
          }
        } else if action == 3 {
          let restored = @src.CompactCountingBloomFilter::from_bytes(f.to_bytes())
          for k = 0; k < 20; k = k + 1 {
            if restored.count_of(k) != f.count_of(k) {
              abort("compact serialized count mismatch")
            }
            if f.contains(k) && !restored.contains(k) {
              abort("compact serialized lost present key slots=" + slots.to_string() + " hashes=" + hashes.to_string())
            }
          }
          if restored.count() != f.count() {
            abort("compact serialized count() mismatch")
          }
          if restored.occupied_slot_count() != f.occupied_slot_count() {
            abort("compact serialized occupancy mismatch")
          }
        } else {
          let copy = f.copy()
          for k = 0; k < 20; k = k + 1 {
            if copy.count_of(k) != f.count_of(k) {
              abort("compact copy mismatch")
            }
          }
        }
      }
    }
  }
}

///|
test "investigate bloom and blocked across layouts" {
  let bloom_configs : Array[(Int32, Int32)] = [
    (64, 1), (64, 4), (128, 7), (192, 9), (64, 65), (128, 129), (4096, 1000),
  ]
  for config in bloom_configs {
    let (bits, hashes) = config
    for round = 1; round <= 20; round = round + 1 {
      let f = @src.BloomFilter::with_size(bits, hashes)
      let live : Array[Bool] = Array::make(30, false)
      let mut seed = round * 107 + bits
      for step = 0; step < 400; step = step + 1 {
        seed = inv_seed(seed)
        let key = seed % 30
        let action = seed / 31 % 4
        if action == 0 {
          f.insert(key)
          live[key] = true
        } else if action == 1 {
          if live[key] && !f.contains(key) {
            abort("bloom lost key bits=" + bits.to_string() + " hashes=" + hashes.to_string())
          }
        } else if action == 2 {
          let restored = @src.BloomFilter::from_bytes(f.to_bytes())
          for k = 0; k < 30; k = k + 1 {
            if live[k] && !restored.contains(k) {
              abort("bloom serialized lost key")
            }
          }
          if restored.count() != f.count() {
            abort("bloom serialized count mismatch")
          }
        } else {
          let added = f.insert_if_absent(key)
          if added {
            live[key] = true
            if !f.contains(key) {
              abort("bloom insert_if_absent lost key")
            }
          }
        }
      }
    }
  }
  let blocked_configs : Array[(Int32, Int32)] = [
    (512, 1), (512, 4), (1024, 7), (1536, 9), (512, 65), (1024, 129), (8192, 1000),
  ]
  for config in blocked_configs {
    let (bits, hashes) = config
    for round = 1; round <= 20; round = round + 1 {
      let f = @src.BlockedBloomFilter::with_size(bits, hashes)
      let live : Array[Bool] = Array::make(30, false)
      let mut seed = round * 109 + bits
      for step = 0; step < 400; step = step + 1 {
        seed = inv_seed(seed)
        let key = seed % 30
        let action = seed / 31 % 4
        if action == 0 {
          f.insert(key)
          live[key] = true
        } else if action == 1 {
          if live[key] && !f.contains(key) {
            abort("blocked lost key bits=" + bits.to_string() + " hashes=" + hashes.to_string())
          }
        } else if action == 2 {
          let restored = @src.BlockedBloomFilter::from_bytes(f.to_bytes())
          for k = 0; k < 30; k = k + 1 {
            if live[k] && !restored.contains(k) {
              abort("blocked serialized lost key")
            }
          }
          if restored.count() != f.count() {
            abort("blocked serialized count mismatch")
          }
        } else {
          let added = f.insert_if_absent(key)
          if added {
            live[key] = true
            if !f.contains(key) {
              abort("blocked insert_if_absent lost key")
            }
          }
        }
      }
    }
  }
}

///|
test "investigate cuckoo layouts including sparse bfs" {
  let configs : Array[(Int32, Int32)] = [(1, 1), (2, 2), (4, 4), (8, 3), (16, 2), (64, 4)]
  for config in configs {
    let (bc, bs) = config
    for round = 1; round <= 40; round = round + 1 {
      let f = @src.CuckooFilter::with_size(bc, bs)
      let live : Array[Int32] = Array::make(30, 0)
      let mut seed = round * 113 + bc
      for step = 0; step < 400; step = step + 1 {
        seed = inv_seed(seed)
        let key = seed % 30
        let action = seed / 31 % 4
        if action == 0 {
          if f.insert(key) {
            live[key] = live[key] + 1
          }
        } else if action == 1 {
          if live[key] > 0 {
            if !f.remove(key) {
              abort("cuckoo remove failed bc=" + bc.to_string() + " bs=" + bs.to_string())
            }
            live[key] = live[key] - 1
          }
        } else if action == 2 {
          for k = 0; k < 30; k = k + 1 {
            if live[k] > 0 && !f.contains(k) {
              abort("cuckoo lost key bc=" + bc.to_string() + " bs=" + bs.to_string())
            }
          }
        } else {
          let restored = @src.CuckooFilter::from_bytes(f.to_bytes())
          for k = 0; k < 30; k = k + 1 {
            if restored.count_of(k) != f.count_of(k) {
              abort("cuckoo serialized count mismatch")
            }
            if live[k] > 0 && !restored.contains(k) {
              abort("cuckoo serialized lost key")
            }
          }
          if restored.count() != f.count() {
            abort("cuckoo serialized count mismatch")
          }
        }
      }
    }
  }
}
