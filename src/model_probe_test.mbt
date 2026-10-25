///|
fn probe_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "probe scalable counting random set operations" {
  let key_count = 24
  for round = 1; round <= 40; round = round + 1 {
    let left = @src.ScalableCountingBloomFilter::new(2, 0.2)
    let right = @src.ScalableCountingBloomFilter::new(2, 0.2)
    let lm : Array[Int32] = Array::make(key_count, 0)
    let rm : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 7919 + 1
    for step = 0; step < 240; step = step + 1 {
      seed = probe_seed(seed)
      let key = seed % key_count
      let action = seed / 31 % 8
      if action == 0 {
        left.insert(key)
        lm[key] = lm[key] + 1
      } else if action == 1 {
        if lm[key] > 0 {
          if !left.remove(key) {
            abort("probe: left remove failed")
          }
          lm[key] = lm[key] - 1
        }
      } else if action == 2 {
        right.insert(key)
        rm[key] = rm[key] + 1
      } else if action == 3 {
        if rm[key] > 0 {
          if !right.remove(key) {
            abort("probe: right remove failed")
          }
          rm[key] = rm[key] - 1
        }
      } else if action == 4 {
        let added = left.insert_if_absent(key)
        if lm[key] > 0 {
          if added {
            abort("probe: insert_if_absent tracked key")
          }
        } else if added {
          lm[key] = 1
        }
      } else if action == 5 {
        for k = 0; k < key_count; k = k + 1 {
          if lm[k] > 0 {
            if !left.contains(k) {
              abort("probe: left lost live key")
            }
            if left.count_of(k) < lm[k] {
              abort("probe: left count below live")
            }
          }
          if rm[k] > 0 {
            if !right.contains(k) {
              abort("probe: right lost live key")
            }
            if right.count_of(k) < rm[k] {
              abort("probe: right count below live")
            }
          }
        }
      } else if action == 6 {
        let restored = @src.ScalableCountingBloomFilter::from_bytes(
          left.to_bytes(),
        )
        for k = 0; k < key_count; k = k + 1 {
          if restored.count_of(k) != lm[k] {
            abort("probe: serialized count mismatch")
          }
          if lm[k] > 0 && !restored.contains(k) {
            abort("probe: serialized lost live key")
          }
        }
        if restored.count() != left.count() {
          abort("probe: serialized total mismatch")
        }
      } else {
        let union = left.union(right)
        let common = left.intersection(right)
        for k = 0; k < key_count; k = k + 1 {
          let want_union = if lm[k] > rm[k] { lm[k] } else { rm[k] }
          let want_common = if lm[k] < rm[k] { lm[k] } else { rm[k] }
          if union.count_of(k) < want_union {
            println("union count below max k=" + k.to_string() + " got=" + union.count_of(k).to_string() + " want=" + want_union.to_string() + " lm=" + lm[k].to_string() + " rm=" + rm[k].to_string())
            abort("probe: union count below max")
          }
          if common.count_of(k) != want_common {
            println("intersection count mismatch k=" + k.to_string() + " got=" + common.count_of(k).to_string() + " want=" + want_common.to_string() + " lm=" + lm[k].to_string() + " rm=" + rm[k].to_string())
            abort("probe: intersection count mismatch")
          }
          if want_union > 0 && !union.contains(k) {
            println("union missing k=" + k.to_string() + " lm=" + lm[k].to_string() + " rm=" + rm[k].to_string())
            abort("probe: union missing key")
          }
          if want_common > 0 && !common.contains(k) {
            println("intersection missing k=" + k.to_string() + " lm=" + lm[k].to_string() + " rm=" + rm[k].to_string())
            abort("probe: intersection missing key")
          }
        }
        let restored_union = @src.ScalableCountingBloomFilter::from_bytes(
          union.to_bytes(),
        )
        for k = 0; k < key_count; k = k + 1 {
          if restored_union.count_of(k) != union.count_of(k) {
            println("union serialized mismatch k=" + k.to_string() + " got=" + restored_union.count_of(k).to_string() + " want=" + union.count_of(k).to_string())
            abort("probe: union serialized count mismatch")
          }
        }
        let restored_common = @src.ScalableCountingBloomFilter::from_bytes(
          common.to_bytes(),
        )
        for k = 0; k < key_count; k = k + 1 {
          if restored_common.count_of(k) != common.count_of(k) {
            println("common serialized mismatch k=" + k.to_string() + " got=" + restored_common.count_of(k).to_string() + " want=" + common.count_of(k).to_string())
            abort("probe: common serialized count mismatch")
          }
        }
        let merged = left.copy()
        merged.merge(right)
        for k = 0; k < key_count; k = k + 1 {
          if merged.count_of(k) != union.count_of(k) {
            println("merge mismatch k=" + k.to_string() + " got=" + merged.count_of(k).to_string() + " want=" + union.count_of(k).to_string())
            abort("probe: merge count mismatch")
          }
        }
      }
    }
  }
}

///|
test "probe cuckoo random set operations" {
  let key_count = 40
  for round = 1; round <= 40; round = round + 1 {
    let left = @src.CuckooFilter::with_size(64, 4)
    let right = @src.CuckooFilter::with_size(64, 4)
    let lm : Array[Int32] = Array::make(key_count, 0)
    let rm : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 104729 + 3
    for step = 0; step < 300; step = step + 1 {
      seed = probe_seed(seed)
      let key = seed % key_count
      let action = seed / 31 % 8
      if action == 0 {
        if left.insert(key) {
          lm[key] = lm[key] + 1
        }
      } else if action == 1 {
        if lm[key] > 0 {
          if !left.remove(key) {
            abort("probe: cuckoo left remove failed")
          }
          lm[key] = lm[key] - 1
        }
      } else if action == 2 {
        if right.insert(key) {
          rm[key] = rm[key] + 1
        }
      } else if action == 3 {
        if rm[key] > 0 {
          if !right.remove(key) {
            abort("probe: cuckoo right remove failed")
          }
          rm[key] = rm[key] - 1
        }
      } else if action == 4 {
        for k = 0; k < key_count; k = k + 1 {
          if lm[k] > 0 && !left.contains(k) {
            abort("probe: cuckoo left lost live key")
          }
          if rm[k] > 0 && !right.contains(k) {
            abort("probe: cuckoo right lost live key")
          }
        }
      } else if action == 5 {
        let restored = @src.CuckooFilter::from_bytes(left.to_bytes())
        for k = 0; k < key_count; k = k + 1 {
          if restored.count_of(k) != left.count_of(k) {
            abort("probe: cuckoo serialized count mismatch")
          }
          if lm[k] > 0 && !restored.contains(k) {
            abort("probe: cuckoo serialized lost live key")
          }
        }
      } else if action == 6 {
        let common = left.intersection(right)
        for k = 0; k < key_count; k = k + 1 {
          if lm[k] > 0 && rm[k] > 0 {
            if !common.contains(k) {
              abort("probe: cuckoo intersection dropped shared key")
            }
            if common.count_of(k) < lm[k].min(rm[k]) {
              abort("probe: cuckoo intersection count too small")
            }
          }
        }
        if !common.is_subset_of(left) || !common.is_subset_of(right) {
          abort("probe: cuckoo intersection not subset")
        }
        let restored = @src.CuckooFilter::from_bytes(common.to_bytes())
        for k = 0; k < key_count; k = k + 1 {
          if restored.count_of(k) != common.count_of(k) {
            abort("probe: cuckoo common serialized count mismatch")
          }
        }
      } else {
        match left.union(right) {
          Some(union) => {
            for k = 0; k < key_count; k = k + 1 {
              if (lm[k] > 0 || rm[k] > 0) && !union.contains(k) {
                abort("probe: cuckoo union missing key")
              }
            }
            if !left.is_subset_of(union) || !right.is_subset_of(union) {
              abort("probe: cuckoo union not superset")
            }
            let restored = @src.CuckooFilter::from_bytes(union.to_bytes())
            for k = 0; k < key_count; k = k + 1 {
              if restored.count_of(k) != union.count_of(k) {
                abort("probe: cuckoo union serialized count mismatch")
              }
            }
          }
          None => ()
        }
      }
    }
  }
}
