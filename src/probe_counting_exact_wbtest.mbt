///|
fn probe_positions_direct(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : Int32,
) -> (Array[Int32], Array[Int32]) {
  let positions : Array[Int32] = []
  let counts : Array[Int32] = []
  let slots = slot_count.to_uint64()
  let mut state = h1
  for i = 0; i < hash_count; i = i + 1 {
    let pos = (state % slots).to_int()
    let mut found = -1
    for j = 0; j < positions.length(); j = j + 1 {
      if positions[j] == pos {
        found = j
        break
      }
    }
    if found >= 0 {
      counts[found] = counts[found] + 1
    } else {
      positions.push(pos)
      counts.push(1)
    }
    state = state + h2
  }
  (positions, counts)
}

///|
fn probe_model_insert(
  counters : Array[UInt64],
  positions : Array[Int32],
  counts : Array[Int32],
  cap : UInt64,
) -> Unit {
  let mut common = 1UL
  let mut any_zero = false
  for i = 0; i < positions.length(); i = i + 1 {
    let occ = counts[i].to_uint64()
    let limit = if occ > cap { cap } else { cap - cap % occ }
    let value = counters[positions[i]]
    if value == 0UL {
      any_zero = true
    }
    let available = if value > limit { 0UL } else { (limit - value) / occ }
    if available < common {
      common = available
    }
  }
  if common > 0UL {
    for i = 0; i < positions.length(); i = i + 1 {
      let occ = counts[i].to_uint64()
      counters[positions[i]] = counters[positions[i]] + common * occ
    }
    return
  }
  if !any_zero {
    return
  }
  for i = 0; i < positions.length(); i = i + 1 {
    let occ = counts[i].to_uint64()
    let limit = if occ > cap { cap } else { cap - cap % occ }
    let value = counters[positions[i]]
    if value < limit {
      let next = value + occ
      counters[positions[i]] = if next > limit { limit } else { next }
    }
  }
}

///|
fn probe_model_conditional_insert(
  counters : Array[UInt64],
  positions : Array[Int32],
  counts : Array[Int32],
  cap : UInt64,
) -> Bool {
  let mut any_zero = false
  for i = 0; i < positions.length(); i = i + 1 {
    if counters[positions[i]] == 0UL {
      any_zero = true
    }
  }
  if !any_zero {
    return false
  }
  for i = 0; i < positions.length(); i = i + 1 {
    let occ = counts[i].to_uint64()
    let limit = if occ > cap { cap } else { cap - cap % occ }
    let value = counters[positions[i]]
    if value < limit {
      let next = value + occ
      counters[positions[i]] = if next > limit { limit } else { next }
    }
  }
  true
}

///|
fn probe_model_remove(
  counters : Array[UInt64],
  positions : Array[Int32],
  counts : Array[Int32],
  cap : UInt64,
) -> Bool {
  for i = 0; i < positions.length(); i = i + 1 {
    let occ = counts[i].to_uint64()
    let required = if occ > cap { cap } else { occ }
    if counters[positions[i]] < required {
      return false
    }
  }
  for i = 0; i < positions.length(); i = i + 1 {
    let occ = counts[i].to_uint64()
    let value = counters[positions[i]]
    counters[positions[i]] = value - (if value < occ { value } else { occ })
  }
  true
}

///|
test "probe counting exact operations against direct probe model" {
  let configs : Array[(Int32, Int32)] = [
    (16,1),(16,2),(16,3),(16,5),(16,7),(16,20),(16,65),(16,130),
    (32,3),(32,20),(32,64),(32,65),(32,130),(32,700),
    (48,7),(48,70),(48,300),(64,64),(64,200),(80,130),(80,700),
    (16,65535),(16,70000),(32,100000),(48,70000),
  ]
  for cfg in configs {
    let slots = cfg.0
    let hashes = cfg.1
    let f = CountingBloomFilter::with_size(slots, hashes)
    let model : Array[UInt64] = Array::make(f.slot_count(), 0UL)
    let keys : Array[String] = []
    let kp : Array[Array[Int32]] = []
    let kc : Array[Array[Int32]] = []
    for k = 0; k < 12; k = k + 1 {
      let key = "probe-" + k.to_string()
      keys.push(key)
      let (h1, h2) = key_hashes(key)
      let (p, c) = probe_positions_direct(h1, h2, hashes, f.slot_count())
      kp.push(p)
      kc.push(c)
    }
    let mut seed = slots * 17 + hashes * 31 + 7
    for step = 0; step < 400; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 12
      let action = seed / 31 % 5
      if step == 372 {
        println("BEFORE step372 actual/model for key=" + key.to_string() + " action=" + action.to_string())
        for qi = 0; qi < kp[key].length(); qi = qi + 1 {
          let pp = kp[key][qi]
          let occ = kc[key][qi].to_uint64()
          let limit = if occ > 15UL { 15UL } else { 15UL - 15UL % occ }
          let value = model[pp]
          let av = if value > limit { 0UL } else { (limit - value) / occ }
          println("pos=" + pp.to_string() + " n=" + occ.to_string() + " val=" + value.to_string() + " act=" + f.counter_at(pp).to_string() + " lim=" + limit.to_string() + " av=" + av.to_string())
        }
      }
      if action == 0 {
        f.insert(keys[key])
        probe_model_insert(model, kp[key], kc[key], 65535UL)
      } else if action == 1 {
        let expected = probe_model_conditional_insert(model, kp[key], kc[key], 65535UL)
        assert_eq(f.insert_if_absent(keys[key]), expected)
      } else if action == 2 {
        let expected = probe_model_remove(model, kp[key], kc[key], 65535UL)
        assert_eq(f.remove(keys[key]), expected)
      } else if action == 3 {
        for p = 0; p < f.slot_count(); p = p + 1 {
          assert_eq(f.counter_at(p), model[p])
        }
      } else {
        let restored = CountingBloomFilter::from_bytes(f.to_bytes())
        for p = 0; p < f.slot_count(); p = p + 1 {
          assert_eq(restored.counter_at(p), model[p])
        }
        assert_eq(restored.count(), f.count())
      }
      let mut mass = 0UL
      for p = 0; p < f.slot_count(); p = p + 1 {
        assert_eq(f.counter_at(p), model[p])
        mass = mass + model[p]
      }
      assert_eq(f.counter_mass, mass)
    }
  }
}

///|
test "probe compact exact operations against direct probe model" {
  let configs : Array[(Int32, Int32)] = [
    (16,1),(16,2),(16,3),(16,5),(16,7),(16,20),(16,65),(16,130),
    (32,3),(32,20),(32,64),(32,65),(32,130),(32,700),
    (48,7),(48,70),(48,300),(64,64),(64,200),(80,130),(80,700),
    (16,65535),(16,70000),(32,100000),(48,70000),
  ]
  for cfg in configs {
    let slots = cfg.0
    let hashes = cfg.1
    let f = CompactCountingBloomFilter::with_size(slots, hashes)
    let model : Array[UInt64] = Array::make(f.slot_count(), 0UL)
    let keys : Array[String] = []
    let kp : Array[Array[Int32]] = []
    let kc : Array[Array[Int32]] = []
    for k = 0; k < 12; k = k + 1 {
      let key = "probe-" + k.to_string()
      keys.push(key)
      let (h1, h2) = key_hashes(key)
      let (p, c) = probe_positions_direct(h1, h2, hashes, f.slot_count())
      kp.push(p)
      kc.push(c)
    }
    let mut seed = slots * 19 + hashes * 37 + 11
    for step = 0; step < 400; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 12
      let action = seed / 31 % 5
      let before : Array[UInt64] = Array::make(f.slot_count(), 0UL)
      for bp = 0; bp < f.slot_count(); bp = bp + 1 {
        before[bp] = model[bp]
      }
      if step == 372 {
        println("BEFORE step372 actual/model for key=" + key.to_string() + " action=" + action.to_string())
        for qi = 0; qi < kp[key].length(); qi = qi + 1 {
          let pp = kp[key][qi]
          let occ = kc[key][qi].to_uint64()
          let limit = if occ > 15UL { 15UL } else { 15UL - 15UL % occ }
          let value = model[pp]
          let av = if value > limit { 0UL } else { (limit - value) / occ }
          println("pos=" + pp.to_string() + " n=" + occ.to_string() + " val=" + value.to_string() + " act=" + f.counter_at(pp).to_string() + " lim=" + limit.to_string() + " av=" + av.to_string())
        }
      }
      if action == 0 {
        f.insert(keys[key])
        probe_model_insert(model, kp[key], kc[key], 15UL)
      } else if action == 1 {
        let expected = probe_model_conditional_insert(model, kp[key], kc[key], 15UL)
        assert_eq(f.insert_if_absent(keys[key]), expected)
      } else if action == 2 {
        let expected = probe_model_remove(model, kp[key], kc[key], 15UL)
        assert_eq(f.remove(keys[key]), expected)
      } else if action == 3 {
        for p = 0; p < f.slot_count(); p = p + 1 {
          assert_eq(f.counter_at(p), model[p])
        }
      } else {
        let restored = CompactCountingBloomFilter::from_bytes(f.to_bytes())
        for p = 0; p < f.slot_count(); p = p + 1 {
          assert_eq(restored.counter_at(p), model[p])
        }
        assert_eq(restored.count(), f.count())
      }
      let mut mass = 0UL
      for p = 0; p < f.slot_count(); p = p + 1 {
        if f.counter_at(p) != model[p] {
          println("MISMATCH slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " step=" + step.to_string() + " action=" + action.to_string() + " key=" + key.to_string() + " pos=" + p.to_string() + " actual=" + f.counter_at(p).to_string() + " model=" + model[p].to_string() + " before=" + before[p].to_string())
          for qi = 0; qi < kp[key].length(); qi = qi + 1 {
            println("entry pos=" + kp[key][qi].to_string() + " count=" + kc[key][qi].to_string() + " actual=" + f.counter_at(kp[key][qi]).to_string() + " before=" + before[kp[key][qi]].to_string())
          }
          let (dh1, dh2) = key_hashes(keys[key])
          let prod = unique_key_positions_fast(dh1, dh2, f.hash_count, f.slot_count.to_uint64())
          println("h1=" + dh1.to_string() + " h2=" + dh2.to_string() + " prodlen=" + prod.length.to_string())
          for qi = 0; qi < prod.length; qi = qi + 1 {
            println("prod pos=" + prod.positions[qi].to_string() + " count=" + prod.counts[qi].to_string())
          }
          panic()
        }
        mass = mass + model[p]
      }
      assert_eq(f.counter_mass, mass)
    }
  }
}

///|
test "probe counting and compact set operations match per-slot model" {
  for round = 1; round <= 40; round = round + 1 {
    let slots = 16 + round % 5 * 16
    let hashes = 1 + round % 9
    let left = CountingBloomFilter::with_size(slots, hashes)
    let right = CountingBloomFilter::with_size(slots, hashes)
    let lmodel : Array[UInt64] = Array::make(left.slot_count(), 0UL)
    let rmodel : Array[UInt64] = Array::make(right.slot_count(), 0UL)
    let mut seed = round * 97 + 13
    for p = 0; p < left.slot_count(); p = p + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let lv = (seed % 65536).to_uint64()
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let rv = (seed % 65536).to_uint64()
      left.set_counter(p, lv)
      right.set_counter(p, rv)
      lmodel[p] = lv
      rmodel[p] = rv
    }
    left.inserted = 10000000
    right.inserted = 20000000
    let union = left.union(right)
    let inter = left.intersection(right)
    let merged = left.copy()
    merged.merge(right)
    assert_eq(merged.inserted, 30000000)
    assert_eq(union.inserted, 30000000)
    assert_eq(inter.inserted, 10000000)
    for p = 0; p < left.slot_count(); p = p + 1 {
      let hi = if lmodel[p] > rmodel[p] { lmodel[p] } else { rmodel[p] }
      let lo = if lmodel[p] < rmodel[p] { lmodel[p] } else { rmodel[p] }
      assert_eq(union.counter_at(p), hi)
      assert_eq(merged.counter_at(p), hi)
      assert_eq(inter.counter_at(p), lo)
    }
    assert_true(left.is_subset_of(union))
    assert_true(right.is_subset_of(union))
    assert_true(inter.is_subset_of(left))
    assert_true(inter.is_subset_of(right))
    ignore(CountingBloomFilter::from_bytes(union.to_bytes()))
    ignore(CountingBloomFilter::from_bytes(inter.to_bytes()))

    let cleft = CompactCountingBloomFilter::with_size(slots, hashes)
    let cright = CompactCountingBloomFilter::with_size(slots, hashes)
    let clmodel : Array[UInt64] = Array::make(cleft.slot_count(), 0UL)
    let crmodel : Array[UInt64] = Array::make(cright.slot_count(), 0UL)
    for p = 0; p < cleft.slot_count(); p = p + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let lv = (seed % 16).to_uint64()
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let rv = (seed % 16).to_uint64()
      cleft.set_counter(p, lv)
      cright.set_counter(p, rv)
      clmodel[p] = lv
      crmodel[p] = rv
    }
    cleft.inserted = 10000000
    cright.inserted = 20000000
    let cunion = cleft.union(cright)
    let cinter = cleft.intersection(cright)
    let cmerged = cleft.copy()
    cmerged.merge(cright)
    assert_eq(cmerged.inserted, 30000000)
    assert_eq(cunion.inserted, 30000000)
    assert_eq(cinter.inserted, 10000000)
    for p = 0; p < cleft.slot_count(); p = p + 1 {
      let hi = if clmodel[p] > crmodel[p] { clmodel[p] } else { crmodel[p] }
      let lo = if clmodel[p] < crmodel[p] { clmodel[p] } else { crmodel[p] }
      assert_eq(cunion.counter_at(p), hi)
      assert_eq(cmerged.counter_at(p), hi)
      assert_eq(cinter.counter_at(p), lo)
    }
    assert_true(cleft.is_subset_of(cunion))
    assert_true(cright.is_subset_of(cunion))
    assert_true(cinter.is_subset_of(cleft))
    assert_true(cinter.is_subset_of(cright))
    ignore(CompactCountingBloomFilter::from_bytes(cunion.to_bytes()))
    ignore(CompactCountingBloomFilter::from_bytes(cinter.to_bytes()))
  }
}
