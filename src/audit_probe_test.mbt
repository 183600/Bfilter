///|
fn audit_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "audit probe counting randomized invariants" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1),
    (16, 4),
    (16, 20),
    (48, 20),
    (16, 300),
    (48, 720),
    (256, 2),
    (64, 65535),
    (32, 70000),
    (80, 540),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 12; round = round + 1 {
      let filter = @src.CountingBloomFilter::with_size(slots, hashes)
      let live : Array[Int32] = Array::make(24, 0)
      let mut seed = round * 97 + slots
      for step = 0; step < 400; step = step + 1 {
        seed = audit_seed(seed)
        let key = seed % 24
        let action = seed / 31 % 5
        if action == 0 {
          filter.insert(key)
          live[key] = live[key] + 1
        } else if action == 1 {
          if live[key] > 0 {
            let a = filter.remove(key)
            if !a {
              abort("audit: counting inserted key removal failed")
            }
            live[key] = live[key] - 1
          }
        } else if action == 2 {
          let a = filter.insert_if_absent(key)
          if a {
            live[key] = live[key] + 1
          }
        } else if action == 3 {
          if live[key] > 0 {
            if !filter.contains(key) {
              abort("audit: live key missing")
            }
            if filter.count_of(key) < live[key] {
              abort("audit: count_of below live multiplicity")
            }
          }
        } else {
          if step % 17 == 0 {
            let restored = @src.CountingBloomFilter::from_bytes(filter.to_bytes())
            if restored.to_bytes() != filter.to_bytes() {
              abort("audit: counting roundtrip mismatch")
            }
            for k = 0; k < 24; k = k + 1 {
              if live[k] > 0 {
                if !restored.contains(k) {
                  abort("audit: restored live key missing")
                }
              }
            }
          }
        }
      }
    }
  }
}

///|
test "audit probe scalable counting randomized invariants" {
  for round = 1; round <= 10; round = round + 1 {
    let filter = @src.ScalableCountingBloomFilter::new(2, 0.01)
    let live : Array[Int32] = Array::make(30, 0)
    let mut seed = round * 1319 + 7
    for step = 0; step < 500; step = step + 1 {
      seed = audit_seed(seed)
      let key = seed % 30
      let action = seed / 31 % 6
      if action == 0 {
        filter.insert(key)
        live[key] = live[key] + 1
      } else if action == 1 {
        if live[key] > 0 {
          if !filter.remove(key) {
            abort("audit: scalable remove of live key failed")
          }
          live[key] = live[key] - 1
        }
      } else if action == 2 {
        let added = filter.insert_if_absent(key)
        if added {
          live[key] = live[key] + 1
        } else if live[key] == 0 {
          // false positive allowed
        }
      } else if action == 3 {
        if filter.count_of(key) != live[key] {
          abort("audit: scalable count_of mismatch")
        }
        if live[key] > 0 && !filter.contains(key) {
          abort("audit: scalable live key missing")
        }
      } else if action == 4 {
        if step % 23 == 0 {
          let restored = @src.ScalableCountingBloomFilter::from_bytes(filter.to_bytes())
          if restored.to_bytes() != filter.to_bytes() {
            abort("audit: scalable counting roundtrip mismatch")
          }
          for k = 0; k < 30; k = k + 1 {
            if restored.count_of(k) != live[k] {
              abort("audit: scalable restored count mismatch")
            }
          }
        }
      } else {
        if step % 41 == 0 {
          let copy = filter.copy()
          let common = filter.intersection(copy)
          for k = 0; k < 30; k = k + 1 {
            if common.count_of(k) != live[k] {
              abort("audit: self intersection changed multiplicity")
            }
          }
          let joined = filter.union(copy)
          for k = 0; k < 30; k = k + 1 {
            if joined.count_of(k) < live[k] {
              abort("audit: self union dropped multiplicity")
            }
          }
          if !filter.is_subset_of(copy) || !copy.is_subset_of(filter) {
            abort("audit: self subset failed")
          }
        }
      }
    }
  }
}

///|
test "audit probe cuckoo randomized invariants" {
  let layouts : Array[(Int32, Int32)] = [(1, 1), (4, 1), (8, 2), (16, 4), (64, 4), (5, 3)]
  for layout in layouts {
    let (buckets, bucket_size) = layout
    for round = 1; round <= 8; round = round + 1 {
      let left = @src.CuckooFilter::with_size(buckets, bucket_size)
      let right = @src.CuckooFilter::with_size(buckets, bucket_size)
      let live_left : Array[Int32] = Array::make(24, 0)
      let live_right : Array[Int32] = Array::make(24, 0)
      let mut seed = round * 241 + buckets * 7 + bucket_size
      for step = 0; step < 300; step = step + 1 {
        seed = audit_seed(seed)
        let key = seed % 24
        let action = seed / 31 % 6
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
            if !left.remove(key) {
              abort("audit: cuckoo left live removal failed")
            }
            live_left[key] = live_left[key] - 1
          }
        } else if action == 3 {
          if live_right[key] > 0 {
            if !right.remove(key) {
              abort("audit: cuckoo right live removal failed")
            }
            live_right[key] = live_right[key] - 1
          }
        } else if action == 4 {
          if live_left[key] > 0 && !left.contains(key) {
            abort("audit: cuckoo left live key missing")
          }
          if live_right[key] > 0 && !right.contains(key) {
            abort("audit: cuckoo right live key missing")
          }
        } else {
          if step % 31 == 0 {
            let restored = @src.CuckooFilter::from_bytes(left.to_bytes())
            if restored.to_bytes() != left.to_bytes() {
              abort("audit: cuckoo roundtrip mismatch")
            }
          }
        }
      }
      let common = left.intersection(right)
      for key = 0; key < 24; key = key + 1 {
        if live_left[key] > 0 && live_right[key] > 0 {
          if !common.contains(key) {
            abort("audit: cuckoo intersection dropped shared key")
          }
        }
      }
      if !common.is_subset_of(left) || !common.is_subset_of(right) {
        abort("audit: cuckoo intersection subset failed")
      }
      if common.count() > left.count().min(right.count()) {
        abort("audit: cuckoo intersection count too large")
      }
      match left.union(right) {
        Some(joined) => {
          for key = 0; key < 24; key = key + 1 {
            if live_left[key] > 0 || live_right[key] > 0 {
              if !joined.contains(key) {
                abort("audit: cuckoo union dropped live key")
              }
            }
          }
          if joined.count() != left.count() + right.count() {
            abort("audit: cuckoo union count mismatch")
          }
        }
        None => ()
      }
    }
  }
}
