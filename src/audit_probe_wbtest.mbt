///|
fn audit_manual_bloom_contains(filter : BloomFilter, h1 : UInt64, h2 : UInt64) -> Bool {
  let bit_count = filter.bit_count.to_uint64()
  let mut state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = (state % bit_count).to_int()
    if (filter.words[pos / 64] & (1UL << (pos % 64))) == 0UL {
      return false
    }
    state = state + h2
  }
  true
}

///|
fn audit_manual_counting_contains(filter : CountingBloomFilter, h1 : UInt64, h2 : UInt64) -> Bool {
  let slot_count = filter.slot_count.to_uint64()
  let mut state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = (state % slot_count).to_int()
    if filter.counter_at(pos) == 0UL {
      return false
    }
    state = state + h2
  }
  true
}

///|
fn audit_manual_compact_contains(filter : CompactCountingBloomFilter, h1 : UInt64, h2 : UInt64) -> Bool {
  let slot_count = filter.slot_count.to_uint64()
  let mut state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = (state % slot_count).to_int()
    if filter.counter_at(pos) == 0UL {
      return false
    }
    state = state + h2
  }
  true
}

///|
fn audit_manual_blocked_contains(filter : BlockedBloomFilter, h1 : UInt64, h2 : UInt64) -> Bool {
  let base = filter.block_base(h1)
  let step = (h2 % 512UL).to_int()
  let mut offset = (h1 % 512UL).to_int()
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = base + offset
    if (filter.words[pos / 64] & (1UL << (pos % 64))) == 0UL {
      return false
    }
    offset = offset + step
    if offset >= 512 {
      offset = offset - 512
    }
  }
  true
}

///|
test "audit probe wide probe shortcuts match full walks" {
  let layouts : Array[(Int32, Int32)] = [
    (64, 65),
    (64, 300),
    (64, 1000),
    (960, 65),
    (960, 500),
    (960, 2000),
    (192, 77),
    (320, 160),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    let bloom = BloomFilter::with_size(slots, hashes)
    let counting = CountingBloomFilter::with_size(slots, hashes)
    let compact = CompactCountingBloomFilter::with_size(slots, hashes)
    let blocked = BlockedBloomFilter::with_size(slots, hashes)
    for i = 0; i < 40; i = i + 1 {
      let key = "wide-" + i.to_string()
      bloom.insert(key)
      counting.insert(key)
      compact.insert(key)
      blocked.insert(key)
    }
    for i = 0; i < 40; i = i + 1 {
      let key = "wide-" + i.to_string() + "-query"
      let (h1, h2) = key_hashes(key)
      let expected_bloom = audit_manual_bloom_contains(bloom, h1, h2)
      if bloom.contains(key) != expected_bloom {
        abort("audit: bloom wide probe mismatch")
      }
      let expected_counting = audit_manual_counting_contains(counting, h1, h2)
      if counting.contains(key) != expected_counting {
        abort("audit: counting wide probe mismatch")
      }
      let expected_compact = audit_manual_compact_contains(compact, h1, h2)
      if compact.contains(key) != expected_compact {
        abort("audit: compact wide probe mismatch")
      }
      let expected_blocked = audit_manual_blocked_contains(blocked, h1, h2)
      if blocked.contains(key) != expected_blocked {
        abort("audit: blocked wide probe mismatch")
      }
    }
  }
}

///|
fn audit_counting_expected_count_of(
  filter : CountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Int32 {
  let slots = filter.slot_count
  let occurrences : Array[Int32] = Array::make(slots, 0)
  let state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = ((state + h2 * i.to_uint64()) % filter.slot_count.to_uint64()).to_int()
    occurrences[pos] = occurrences[pos] + 1
  }
  let limit = 65535
  let mut minimum = limit
  let mut fallback = limit
  let mut have_estimate = false
  for pos = 0; pos < slots; pos = pos + 1 {
    if occurrences[pos] == 0 {
      continue
    }
    let value = filter.counter_at(pos).to_int()
    if value <= 0 {
      return 0
    }
    if value < fallback {
      fallback = value
    }
    let occ = occurrences[pos]
    if occ <= limit {
      let estimate = if value < occ { 1 } else { value / occ }
      if !have_estimate || estimate < minimum {
        minimum = estimate
        have_estimate = true
      }
    }
  }
  if have_estimate { minimum } else { fallback }
}

///|
fn audit_compact_expected_count_of(
  filter : CompactCountingBloomFilter,
  h1 : UInt64,
  h2 : UInt64,
) -> Int32 {
  let slots = filter.slot_count
  let occurrences : Array[Int32] = Array::make(slots, 0)
  let state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = ((state + h2 * i.to_uint64()) % filter.slot_count.to_uint64()).to_int()
    occurrences[pos] = occurrences[pos] + 1
  }
  let limit = 15
  let mut minimum = limit
  let mut fallback = limit
  let mut have_estimate = false
  for pos = 0; pos < slots; pos = pos + 1 {
    if occurrences[pos] == 0 {
      continue
    }
    let value = filter.counter_at(pos).to_int()
    if value <= 0 {
      return 0
    }
    if value < fallback {
      fallback = value
    }
    let occ = occurrences[pos]
    if occ <= limit {
      let estimate = if value < occ { 1 } else { value / occ }
      if !have_estimate || estimate < minimum {
        minimum = estimate
        have_estimate = true
      }
    }
  }
  if have_estimate { minimum } else { fallback }
}

///|
test "audit probe count_of matches full occurrence walk" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1),
    (16, 4),
    (16, 20),
    (48, 20),
    (80, 15),
    (48, 720),
    (32, 17),
    (64, 70),
    (16, 300),
    (32, 70000),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 6; round = round + 1 {
      let counting = CountingBloomFilter::with_size(slots, hashes)
      let compact = CompactCountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 313 + slots + hashes
      for step = 0; step < 200; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 16
        let action = seed / 31 % 3
        if action == 0 {
          counting.insert(key)
          compact.insert(key)
        } else if action == 1 {
          ignore(counting.remove(key))
          ignore(compact.remove(key))
        } else {
          let c = counting.count_of(key)
          let expected_c = audit_counting_expected_count_of(counting, key_hashes(key).0, key_hashes(key).1)
          if c != expected_c {
            abort("audit: counting count_of mismatch")
          }
          let p = compact.count_of(key)
          let expected_p = audit_compact_expected_count_of(compact, key_hashes(key).0, key_hashes(key).1)
          if p != expected_p {
            abort("audit: compact count_of mismatch")
          }
        }
      }
    }
  }
}

///|
fn audit_manual_bloom_insert_if_absent(filter : BloomFilter, h1 : UInt64, h2 : UInt64) -> Bool {
  let bit_count = filter.bit_count.to_uint64()
  let mut state = h1
  let mut index = -1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = (state % bit_count).to_int()
    if (filter.words[pos / 64] & (1UL << (pos % 64))) == 0UL {
      index = i
      break
    }
    state = state + h2
  }
  if index < 0 {
    return false
  }
  let mut s = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    if i >= index {
      let pos = (s % bit_count).to_int()
      filter.words[pos / 64] = filter.words[pos / 64] | (1UL << (pos % 64))
    }
    s = s + h2
  }
  filter.inserted = filter.inserted + 1
  true
}

///|
fn audit_manual_counting_insert_if_absent(filter : CountingBloomFilter, h1 : UInt64, h2 : UInt64) -> Bool {
  let slots = filter.slot_count
  let occurrences : Array[UInt64] = Array::make(slots, 0UL)
  let state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = ((state + h2 * i.to_uint64()) % filter.slot_count.to_uint64()).to_int()
    occurrences[pos] = occurrences[pos] + 1UL
  }
  let mut any_zero = false
  for pos = 0; pos < slots; pos = pos + 1 {
    if occurrences[pos] > 0UL && filter.counter_at(pos) == 0UL {
      any_zero = true
    }
  }
  if !any_zero {
    return false
  }
  let mut wanted = 1UL
  for pos = 0; pos < slots; pos = pos + 1 {
    let occ = occurrences[pos]
    if occ == 0UL {
      continue
    }
    let limit = counting_position_limit(occ)
    let value = filter.counter_at(pos)
    let available = if value > limit { 0UL } else { (limit - value) / occ }
    if available < wanted {
      wanted = available
    }
  }
  if wanted > 0UL {
    for pos = 0; pos < slots; pos = pos + 1 {
      let occ = occurrences[pos]
      if occ > 0UL {
        filter.set_counter(pos, filter.counter_at(pos) + wanted * occ)
      }
    }
  } else {
    for pos = 0; pos < slots; pos = pos + 1 {
      let occ = occurrences[pos]
      if occ > 0UL {
        let limit = counting_position_limit(occ)
        let value = filter.counter_at(pos)
        if value < limit {
          let raised = value + occ
          filter.set_counter(pos, if raised > limit { limit } else { raised })
        }
      }
    }
  }
  filter.inserted = filter.inserted + 1
  true
}

///|
fn audit_manual_compact_insert_if_absent(filter : CompactCountingBloomFilter, h1 : UInt64, h2 : UInt64) -> Bool {
  let slots = filter.slot_count
  let occurrences : Array[Int32] = Array::make(slots, 0)
  let state = h1
  for i = 0; i < filter.hash_count; i = i + 1 {
    let pos = ((state + h2 * i.to_uint64()) % filter.slot_count.to_uint64()).to_int()
    occurrences[pos] = occurrences[pos] + 1
  }
  let mut any_zero = false
  for pos = 0; pos < slots; pos = pos + 1 {
    if occurrences[pos] > 0 && filter.counter_at(pos) == 0UL {
      any_zero = true
    }
  }
  if !any_zero {
    return false
  }
  let mut common = 1UL
  for pos = 0; pos < slots; pos = pos + 1 {
    let occ = occurrences[pos]
    if occ == 0 {
      continue
    }
    let o = occ.to_uint64()
    let limit = compact_position_limit(o)
    let value = filter.counter_at(pos)
    let available = if value > limit { 0UL } else { (limit - value) / o }
    if available < common {
      common = available
    }
  }
  if common > 0UL {
    for pos = 0; pos < slots; pos = pos + 1 {
      let occ = occurrences[pos]
      if occ > 0 {
        filter.set_counter(pos, filter.counter_at(pos) + common * occ.to_uint64())
      }
    }
  } else {
    for pos = 0; pos < slots; pos = pos + 1 {
      let occ = occurrences[pos]
      if occ > 0 {
        let o = occ.to_uint64()
        let limit = compact_position_limit(o)
        let value = filter.counter_at(pos)
        if value < limit {
          let raised = value + o
          filter.set_counter(pos, if raised > limit { limit } else { raised })
        }
      }
    }
  }
  filter.inserted = filter.inserted + 1
  true
}

///|
test "audit probe conditional insertion matches full occurrence walk" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1),
    (16, 4),
    (16, 20),
    (48, 20),
    (48, 720),
    (32, 17),
    (64, 70),
    (16, 300),
    (32, 70000),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 6; round = round + 1 {
      let bloom = BloomFilter::with_size(slots, hashes)
      let bloom_ref = BloomFilter::with_size(slots, hashes)
      let counting = CountingBloomFilter::with_size(slots, hashes)
      let counting_ref = CountingBloomFilter::with_size(slots, hashes)
      let compact = CompactCountingBloomFilter::with_size(slots, hashes)
      let compact_ref = CompactCountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 577 + slots + hashes
      for step = 0; step < 150; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 16
        let (h1, h2) = key_hashes(key)
        let action = seed / 31 % 4
        if action == 0 {
          bloom.insert(key)
          bloom_ref.insert(key)
          counting.insert(key)
          counting_ref.insert(key)
          compact.insert(key)
          compact_ref.insert(key)
        } else if action == 1 {
          ignore(counting.remove(key))
          ignore(counting_ref.remove(key))
          ignore(compact.remove(key))
          ignore(compact_ref.remove(key))
        } else if action == 2 {
          let a = bloom.insert_if_absent(key)
          let b = audit_manual_bloom_insert_if_absent(bloom_ref, h1, h2)
          if a != b {
            abort("audit: bloom conditional insertion mismatch")
          }
        } else {
          let a = counting.insert_if_absent(key)
          let b = audit_manual_counting_insert_if_absent(counting_ref, h1, h2)
          if a != b {
            abort("audit: counting conditional insertion mismatch")
          }
          let c = compact.insert_if_absent(key)
          let d = audit_manual_compact_insert_if_absent(compact_ref, h1, h2)
          if c != d {
            abort("audit: compact conditional insertion mismatch")
          }
        }
        if bloom.to_bytes() != bloom_ref.to_bytes() {
          abort("audit: bloom conditional state mismatch")
        }
        if counting.to_bytes() != counting_ref.to_bytes() {
          abort("audit: counting conditional state mismatch")
        }
        if compact.to_bytes() != compact_ref.to_bytes() {
          abort("audit: compact conditional state mismatch")
        }
      }
    }
  }
}

///|
test "audit probe packed lane helpers match per-lane reference" {
  let mut seed = 1234567
  for round = 0; round < 2000; round = round + 1 {
    let mut a = 0UL
    let mut b = 0UL
    let mut expected_max = 0UL
    let mut expected_min = 0UL
    let mut expected_nonzero = 0UL
    let mut expected_mass = 0UL
    for lane = 0; lane < 16; lane = lane + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let lv = seed % 16
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let rv = seed % 16
      a = a | (lv.to_uint64() << (lane * 4))
      b = b | (rv.to_uint64() << (lane * 4))
      let hi = if lv >= rv { lv } else { rv }
      let lo = if lv <= rv { lv } else { rv }
      expected_max = expected_max | (hi.to_uint64() << (lane * 4))
      expected_min = expected_min | (lo.to_uint64() << (lane * 4))
      if lv > 0 {
        expected_nonzero = expected_nonzero | (8UL << (lane * 4))
      }
      expected_mass = expected_mass + lv.to_uint64()
    }
    if compact_lane_max(a, b) != expected_max {
      abort("audit: compact lane max mismatch")
    }
    if compact_lane_min(a, b) != expected_min {
      abort("audit: compact lane min mismatch")
    }
    if compact_nonzero_lanes(a) != expected_nonzero {
      abort("audit: compact nonzero mismatch")
    }
    if compact_word_mass(a) != expected_mass {
      abort("audit: compact word mass mismatch")
    }
    let mut ca = 0UL
    let mut cb = 0UL
    let mut cmax = 0UL
    let mut cmin = 0UL
    let mut cnon = 0UL
    let mut cmass = 0UL
    for lane = 0; lane < 4; lane = lane + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let lv = seed % 65536
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let rv = seed % 65536
      ca = ca | (lv.to_uint64() << (lane * 16))
      cb = cb | (rv.to_uint64() << (lane * 16))
      let hi = if lv >= rv { lv } else { rv }
      let lo = if lv <= rv { lv } else { rv }
      cmax = cmax | (hi.to_uint64() << (lane * 16))
      cmin = cmin | (lo.to_uint64() << (lane * 16))
      if lv > 0 {
        cnon = cnon | (0x8000UL << (lane * 16))
      }
      cmass = cmass + lv.to_uint64()
    }
    if counting_lane_max(ca, cb) != cmax {
      abort("audit: counting lane max mismatch")
    }
    if counting_lane_min(ca, cb) != cmin {
      abort("audit: counting lane min mismatch")
    }
    if counting_nonzero_lanes(ca) != cnon {
      abort("audit: counting nonzero mismatch")
    }
    if counting_word_mass(ca) != cmass {
      abort("audit: counting word mass mismatch")
    }
  }
}

///|
test "audit probe both zero-slice bloom merge with count-only source" {
  let receiver : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 0,
  }
  let source : ScalableBloomFilter = {
    slices: [],
    capacities: [],
    initial_capacity: 2,
    target_rate: 0.01,
    inserted: 5,
  }
  receiver.merge(source)
  if receiver.count() != 5 {
    abort("audit: expected conservative count preserved")
  }
  if receiver.slice_count() == 0 {
    abort("audit: expected normalized slice")
  }
  let restored = ScalableBloomFilter::from_bytes(receiver.to_bytes())
  if restored.count() != 5 {
    abort("audit: expected count after roundtrip")
  }
}
