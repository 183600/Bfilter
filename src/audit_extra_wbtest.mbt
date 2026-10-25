///|
fn audit_extra_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
fn audit_extra_positions(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : Int32,
) -> FixedArray[Int32] {
  let result = FixedArray::make(slot_count, 0)
  let slots = slot_count.to_uint64()
  let mut state = h1
  for i = 0; i < hash_count; i = i + 1 {
    let pos = (state % slots).to_int()
    result[pos] = result[pos] + 1
    state = state + h2
  }
  result
}

///|
test "audit extra counting counters match full probe enumeration" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1),
    (16, 2),
    (16, 20),
    (32, 65),
    (32, 130),
    (48, 70),
    (64, 200),
    (80, 300),
    (256, 700),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 8; round = round + 1 {
      let filter = CountingBloomFilter::with_size(slots, hashes)
      let live : Array[Int32] = Array::make(8, 0)
      let expected : FixedArray[FixedArray[Int32]] = FixedArray::make(
        8,
        FixedArray::make(slots, 0),
      )
      for key = 0; key < 8; key = key + 1 {
        let id = key_hashes(key)
        expected[key] = audit_extra_positions(id.0, id.1, hashes, slots)
      }
      let mut seed = round * 101 + slots * 3 + hashes
      for step = 0; step < 80; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % 8
        let action = seed / 31 % 3
        if action == 0 {
          filter.insert(key)
          live[key] = live[key] + 1
        } else if action == 1 {
          if live[key] > 0 {
            if !filter.remove(key) {
              abort("audit extra: live remove failed")
            }
            live[key] = live[key] - 1
          }
        } else if live[key] > 0 {
          if !filter.contains(key) {
            abort("audit extra: live key missing")
          }
          if filter.count_of(key) < live[key] {
            abort("audit extra: count_of below live")
          }
        }
        let mut total = 0
        for pos = 0; pos < slots; pos = pos + 1 {
          let mut want = 0UL
          for key = 0; key < 8; key = key + 1 {
            want = want + expected[key][pos].to_uint64() * live[key].to_uint64()
          }
          let got = filter.counter_at(pos)
          if got != want {
            abort("audit extra: counter mismatch")
          }
          total = total + want.to_int()
        }
        if filter.counter_mass.to_int() != total {
          abort("audit extra: counter mass mismatch")
        }
        let mut live_total = 0
        for key = 0; key < 8; key = key + 1 {
          live_total = live_total + live[key]
        }
        if filter.count() != live_total {
          abort("audit extra: insertion count mismatch")
        }
      }
    }
  }
}

///|
fn audit_extra_bloom_bits(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  bit_count : Int32,
  bits : FixedArray[Bool],
) -> Unit {
  let m = bit_count.to_uint64()
  let mut state = h1
  for i = 0; i < hash_count; i = i + 1 {
    bits[(state % m).to_int()] = true
    state = state + h2
  }
}

///|
test "audit extra bloom bits match full probe enumeration" {
  let layouts : Array[(Int32, Int32)] = [
    (64, 1),
    (64, 5),
    (128, 65),
    (192, 70),
    (256, 130),
    (320, 300),
    (512, 700),
  ]
  for layout in layouts {
    let (bits_count, hashes) = layout
    for round = 1; round <= 8; round = round + 1 {
      let filter = BloomFilter::with_size(bits_count, hashes)
      let live : Array[Bool] = Array::make(8, false)
      let expected : FixedArray[FixedArray[Bool]] = FixedArray::make(
        8,
        FixedArray::make(bits_count, false),
      )
      for key = 0; key < 8; key = key + 1 {
        let id = key_hashes(key)
        expected[key] = FixedArray::make(bits_count, false)
        audit_extra_bloom_bits(id.0, id.1, hashes, bits_count, expected[key])
      }
      let mut seed = round * 103 + bits_count + hashes
      for step = 0; step < 60; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % 8
        if seed / 31 % 4 == 0 {
          filter.insert(key)
          live[key] = true
        } else if live[key] && !filter.contains(key) {
          abort("audit extra: bloom live key missing")
        }
        for pos = 0; pos < bits_count; pos = pos + 1 {
          let mut want = false
          for key = 0; key < 8; key = key + 1 {
            if live[key] && expected[key][pos] {
              want = true
            }
          }
          let got = ((filter.words[pos / 64] >> (pos % 64)) & 1UL) != 0UL
          if got != want {
            abort("audit extra: bloom bit mismatch")
          }
        }
      }
    }
  }
}

///|
test "audit extra cuckoo high-load unions and intersections" {
  let layouts : Array[(Int32, Int32)] = [
    (1, 1),
    (1, 4),
    (2, 2),
    (4, 1),
    (4, 4),
    (8, 2),
    (16, 4),
    (64, 4),
  ]
  for layout in layouts {
    let (bucket_count, bucket_size) = layout
    for round = 1; round <= 40; round = round + 1 {
      let left = CuckooFilter::with_size(bucket_count, bucket_size)
      let right = CuckooFilter::with_size(bucket_count, bucket_size)
      let keys = (bucket_count * bucket_size * 2).max(16)
      let live_left : Array[Int32] = Array::make(keys, 0)
      let live_right : Array[Int32] = Array::make(keys, 0)
      let mut seed = round * 257 + bucket_count * 11 + bucket_size
      for step = 0; step < 400; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % keys
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
          if live_left[key] > 0 && left.remove(key) {
            live_left[key] = live_left[key] - 1
          }
        } else if live_right[key] > 0 && right.remove(key) {
          live_right[key] = live_right[key] - 1
        }
      }
      let left_before = left.to_bytes()
      let right_before = right.to_bytes()
      let common = left.intersection(right)
      for key = 0; key < keys; key = key + 1 {
        if live_left[key] > 0 && live_right[key] > 0 {
          let expected = live_left[key].min(live_right[key])
          if !common.contains(key) {
            abort("audit extra: cuckoo shared key dropped")
          }
          if common.count_of(key) < expected {
            abort("audit extra: cuckoo intersection multiplicity too small")
          }
        }
      }
      if !common.is_subset_of(left) || !common.is_subset_of(right) {
        abort("audit extra: cuckoo intersection subset failed")
      }
      if common.count() > left.count().min(right.count()) {
        abort("audit extra: cuckoo intersection count too large")
      }
      match left.union(right) {
        Some(combined) => {
          if combined.count() != left.count() + right.count() {
            abort("audit extra: cuckoo union count mismatch")
          }
          for key = 0; key < keys; key = key + 1 {
            if (live_left[key] > 0 || live_right[key] > 0) &&
              !combined.contains(key) {
              abort("audit extra: cuckoo union dropped key")
            }
          }
          if !left.is_subset_of(combined) || !right.is_subset_of(combined) {
            abort("audit extra: cuckoo union subset failed")
          }
          let restored = CuckooFilter::from_bytes(combined.to_bytes())
          if restored.to_bytes() != combined.to_bytes() {
            abort("audit extra: cuckoo union roundtrip mismatch")
          }
        }
        None => ()
      }
      if left.to_bytes() != left_before || right.to_bytes() != right_before {
        abort("audit extra: cuckoo set operation mutated an input")
      }
      let merged = left.copy()
      if merged.merge(right) {
        match left.union(right) {
          Some(combined) =>
            if merged.to_bytes() != combined.to_bytes() {
              abort("audit extra: cuckoo merge differs from union")
            }
          None => abort("audit extra: cuckoo merge succeeded where union failed")
        }
      } else {
        if merged.to_bytes() != left_before {
          abort("audit extra: failed cuckoo merge mutated receiver")
        }
      }
    }
  }
}

///|
test "audit extra scalable bloom subset and disjoint guarantees" {
  for round = 1; round <= 30; round = round + 1 {
    let left = ScalableBloomFilter::new(2, 0.01)
    let right = ScalableBloomFilter::new(2, 0.01)
    let mut seed = round * 397
    for step = 0; step < 120; step = step + 1 {
      seed = audit_extra_seed(seed)
      let key = seed % 40
      if seed / 31 % 2 == 0 {
        left.insert(key)
      } else {
        right.insert(key)
      }
    }
    if left.is_subset_of(right) {
      for key = 0; key < 40; key = key + 1 {
        if left.contains(key) && !right.contains(key) {
          abort("audit extra: false scalable bloom subset")
        }
      }
      for key = 40; key < 80; key = key + 1 {
        if left.contains(key) && !right.contains(key) {
          abort("audit extra: false scalable bloom subset probe")
        }
      }
    }
    if left.is_disjoint_from(right) {
      for key = 0; key < 80; key = key + 1 {
        if left.contains(key) && right.contains(key) {
          abort("audit extra: false scalable bloom disjoint")
        }
      }
    }
  }
}

///|
test "audit extra scalable counting subset and disjoint guarantees" {
  for round = 1; round <= 30; round = round + 1 {
    let left = ScalableCountingBloomFilter::new(2, 0.01)
    let right = ScalableCountingBloomFilter::new(2, 0.01)
    let mut seed = round * 401
    for step = 0; step < 150; step = step + 1 {
      seed = audit_extra_seed(seed)
      let key = seed % 40
      let which = seed / 31 % 4
      if which == 0 {
        left.insert(key)
      } else if which == 1 {
        right.insert(key)
      } else if which == 2 {
        if left.count_of(key) > 0 {
          left.remove(key) |> ignore
        }
      } else if right.count_of(key) > 0 {
        right.remove(key) |> ignore
      }
    }
    if left.is_subset_of(right) {
      for key = 0; key < 80; key = key + 1 {
        if left.contains(key) && !right.contains(key) {
          abort("audit extra: false scalable counting subset")
        }
      }
    }
    if left.is_disjoint_from(right) {
      for key = 0; key < 80; key = key + 1 {
        if left.contains(key) && right.contains(key) {
          abort("audit extra: false scalable counting disjoint")
        }
      }
    }
  }
}

///|
test "audit extra cuckoo subset and disjoint guarantees" {
  let layouts : Array[(Int32, Int32)] = [(4, 4), (8, 2), (16, 4)]
  for layout in layouts {
    let (bc, bs) = layout
    for round = 1; round <= 30; round = round + 1 {
      let left = CuckooFilter::with_size(bc, bs)
      let right = CuckooFilter::with_size(bc, bs)
      let mut seed = round * 409 + bc
      for step = 0; step < 150; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % 60
        let which = seed / 31 % 4
        if which == 0 {
          left.insert(key) |> ignore
        } else if which == 1 {
          right.insert(key) |> ignore
        } else if which == 2 {
          left.remove(key) |> ignore
        } else {
          right.remove(key) |> ignore
        }
      }
      if left.is_subset_of(right) {
        for key = 0; key < 120; key = key + 1 {
          if left.contains(key) && !right.contains(key) {
            abort("audit extra: false cuckoo subset")
          }
        }
      }
      if left.is_disjoint_from(right) {
        for key = 0; key < 120; key = key + 1 {
          if left.contains(key) && right.contains(key) {
            abort("audit extra: false cuckoo disjoint")
          }
        }
      }
    }
  }
}

///|
test "audit extra counting subset and disjoint guarantees" {
  let layouts : Array[(Int32, Int32)] = [(16, 4), (32, 20), (48, 70), (80, 300)]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 20; round = round + 1 {
      let left = CountingBloomFilter::with_size(slots, hashes)
      let right = CountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 419 + slots
      for step = 0; step < 150; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % 40
        let which = seed / 31 % 4
        if which == 0 {
          left.insert(key)
        } else if which == 1 {
          right.insert(key)
        } else if which == 2 {
          left.remove(key) |> ignore
        } else {
          right.remove(key) |> ignore
        }
      }
      if left.is_subset_of(right) {
        for key = 0; key < 80; key = key + 1 {
          if left.contains(key) && !right.contains(key) {
            abort("audit extra: false counting subset")
          }
        }
      }
      if left.is_disjoint_from(right) {
        for key = 0; key < 80; key = key + 1 {
          if left.contains(key) && right.contains(key) {
            abort("audit extra: false counting disjoint")
          }
        }
      }
    }
  }
}


///|
test "audit extra compact set operations preserve reported keys" {
  let layouts : Array[(Int32, Int32)] = [(16, 1), (16, 4), (16, 20), (48, 70), (256, 300)]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 12; round = round + 1 {
      let left = CompactCountingBloomFilter::with_size(slots, hashes)
      let right = CompactCountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 431 + slots + hashes
      for step = 0; step < 160; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % 32
        let which = seed / 31 % 4
        if which == 0 {
          left.insert(key)
        } else if which == 1 {
          right.insert(key)
        } else if which == 2 {
          left.remove(key) |> ignore
        } else {
          right.remove(key) |> ignore
        }
      }
      let left_before = left.to_bytes()
      let right_before = right.to_bytes()
      let left_keys : Array[Bool] = Array::make(64, false)
      let right_keys : Array[Bool] = Array::make(64, false)
      for key = 0; key < 64; key = key + 1 {
        left_keys[key] = left.contains(key)
        right_keys[key] = right.contains(key)
      }
      let common = left.intersection(right)
      let joined = left.union(right)
      let merged = left.copy()
      merged.merge(right)
      for key = 0; key < 64; key = key + 1 {
        if (left_keys[key] || right_keys[key]) && !joined.contains(key) {
          abort("audit extra: compact union dropped reported key")
        }
        if left_keys[key] && right_keys[key] && !common.contains(key) {
          abort("audit extra: compact intersection dropped shared key")
        }
        if !merged.contains(key) && joined.contains(key) {
          abort("audit extra: compact merge lost union key")
        }
      }
      if joined.count() != left.count() + right.count() {
        abort("audit extra: compact union count mismatch")
      }
      if common.count() != left.count().min(right.count()) {
        abort("audit extra: compact intersection count mismatch")
      }
      if !common.is_subset_of(left) || !common.is_subset_of(right) {
        abort("audit extra: compact intersection subset failed")
      }
      if !left.is_subset_of(joined) || !right.is_subset_of(joined) {
        abort("audit extra: compact union subset failed")
      }
      if merged.to_bytes() != joined.to_bytes() {
        abort("audit extra: compact merge differs from union")
      }
      if left.to_bytes() != left_before || right.to_bytes() != right_before {
        abort("audit extra: compact set ops mutated an input")
      }
      let restored = CompactCountingBloomFilter::from_bytes(joined.to_bytes())
      if restored.to_bytes() != joined.to_bytes() {
        abort("audit extra: compact union roundtrip mismatch")
      }
      let restored_common = CompactCountingBloomFilter::from_bytes(
        common.to_bytes(),
      )
      if restored_common.to_bytes() != common.to_bytes() {
        abort("audit extra: compact intersection roundtrip mismatch")
      }
    }
  }
}

///|
test "audit extra counting set operations preserve reported keys" {
  let layouts : Array[(Int32, Int32)] = [(16, 1), (16, 4), (16, 20), (48, 70), (256, 300)]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 10; round = round + 1 {
      let left = CountingBloomFilter::with_size(slots, hashes)
      let right = CountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 433 + slots + hashes
      for step = 0; step < 140; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % 32
        let which = seed / 31 % 4
        if which == 0 {
          left.insert(key)
        } else if which == 1 {
          right.insert(key)
        } else if which == 2 {
          left.remove(key) |> ignore
        } else {
          right.remove(key) |> ignore
        }
      }
      let joined = left.union(right)
      let common = left.intersection(right)
      for key = 0; key < 64; key = key + 1 {
        let in_left = left.contains(key)
        let in_right = right.contains(key)
        if (in_left || in_right) && !joined.contains(key) {
          abort("audit extra: counting union dropped reported key")
        }
        if in_left && in_right && !common.contains(key) {
          abort("audit extra: counting intersection dropped shared key")
        }
      }
      if joined.count() != left.count() + right.count() {
        abort("audit extra: counting union count mismatch")
      }
      if common.count() != left.count().min(right.count()) {
        abort("audit extra: counting intersection count mismatch")
      }
      if !common.is_subset_of(left) || !common.is_subset_of(right) {
        abort("audit extra: counting intersection subset failed")
      }
      if !left.is_subset_of(joined) || !right.is_subset_of(joined) {
        abort("audit extra: counting union subset failed")
      }
      let merged = left.copy()
      merged.merge(right)
      if merged.to_bytes() != joined.to_bytes() {
        abort("audit extra: counting merge differs from union")
      }
    }
  }
}

///|
test "audit extra bloom and blocked set operations preserve reported keys" {
  let layouts : Array[(Int32, Int32)] = [(64, 1), (64, 5), (128, 65), (512, 300)]
  for layout in layouts {
    let (bits, hashes) = layout
    for round = 1; round <= 10; round = round + 1 {
      let bloom_left = BloomFilter::with_size(bits, hashes)
      let bloom_right = BloomFilter::with_size(bits, hashes)
      let blocked_left = BlockedBloomFilter::with_size(bits, hashes)
      let blocked_right = BlockedBloomFilter::with_size(bits, hashes)
      let mut seed = round * 439 + bits + hashes
      for step = 0; step < 120; step = step + 1 {
        seed = audit_extra_seed(seed)
        let key = seed % 32
        let which = seed / 31 % 4
        if which == 0 {
          bloom_left.insert(key)
          blocked_left.insert(key)
        } else if which == 1 {
          bloom_right.insert(key)
          blocked_right.insert(key)
        }
      }
      let bloom_union = bloom_left.union(bloom_right)
      let bloom_common = bloom_left.intersection(bloom_right)
      let blocked_union = blocked_left.union(blocked_right)
      let blocked_common = blocked_left.intersection(blocked_right)
      for key = 0; key < 64; key = key + 1 {
        let bloom_l = bloom_left.contains(key)
        let bloom_r = bloom_right.contains(key)
        if (bloom_l || bloom_r) && !bloom_union.contains(key) {
          abort("audit extra: bloom union dropped reported key")
        }
        if bloom_l && bloom_r && !bloom_common.contains(key) {
          abort("audit extra: bloom intersection dropped shared key")
        }
        let blocked_l = blocked_left.contains(key)
        let blocked_r = blocked_right.contains(key)
        if (blocked_l || blocked_r) && !blocked_union.contains(key) {
          abort("audit extra: blocked union dropped reported key")
        }
        if blocked_l && blocked_r && !blocked_common.contains(key) {
          abort("audit extra: blocked intersection dropped shared key")
        }
      }
      if bloom_union.count() != bloom_left.count() + bloom_right.count() {
        abort("audit extra: bloom union count mismatch")
      }
      if blocked_union.count() !=
        blocked_left.count() + blocked_right.count() {
        abort("audit extra: blocked union count mismatch")
      }
      if bloom_common.count() !=
        bloom_left.count().min(bloom_right.count()) {
        abort("audit extra: bloom intersection count mismatch")
      }
      if blocked_common.count() !=
        blocked_left.count().min(blocked_right.count()) {
        abort("audit extra: blocked intersection count mismatch")
      }
    }
  }
}
