///|
fn scratch_naive_positions(
  h1 : UInt64,
  h2 : UInt64,
  hash_count : Int32,
  slot_count : Int32,
) -> Array[(Int32, Int32)] {
  let counts : Array[Int32] = Array::make(slot_count, 0)
  let mut state = h1
  for i = 0; i < hash_count; i = i + 1 {
    let pos = (state % slot_count.to_uint64()).to_int()
    counts[pos] = counts[pos] + 1
    state = state + h2
  }
  let result : Array[(Int32, Int32)] = []
  for pos = 0; pos < slot_count; pos = pos + 1 {
    if counts[pos] > 0 {
      result.push((pos, counts[pos]))
    }
  }
  result
}

///|
test "scratch unique positions match naive probe walk" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1), (16, 63), (16, 64), (16, 65), (16, 1000), (16, 16385),
    (32, 65), (32, 70000), (48, 65), (48, 1000), (64, 65), (64, 16385),
    (80, 65), (80, 1000), (96, 20000), (128, 20000), (256, 70000),
    (100, 130), (100, 16385), (200, 20000),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 0; round < 12; round = round + 1 {
      let h1 = mix64((round.to_uint64() + 1UL) * 0x9E3779B97F4A7C15UL)
      let h2 = mix64(h1 ^ (round.to_uint64() * 0xBF58476D1CE4E5B9UL)) | 1UL
      let expected = scratch_naive_positions(h1, h2, hashes, slots)
      let actual = unique_key_positions_fast(
        h1, h2, hashes, slots.to_uint64(),
      )
      let got : Array[(Int32, Int32)] = []
      for i = 0; i < actual.length; i = i + 1 {
        got.push((actual.positions[i], actual.counts[i]))
      }
      got.sort_by(fn(a, b) { a.0 - b.0 })
      if got != expected {
        println("position mismatch slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " round=" + round.to_string() + " got_len=" + got.length().to_string() + " expected_len=" + expected.length().to_string())
        for i = 0; i < got.length() && i < 5; i = i + 1 {
          println(" got[" + i.to_string() + "]=" + got[i].0.to_string() + "x" + got[i].1.to_string())
        }
        for i = 0; i < expected.length() && i < 5; i = i + 1 {
          println(" exp[" + i.to_string() + "]=" + expected[i].0.to_string() + "x" + expected[i].1.to_string())
        }
        panic()
      }
    }
  }
}

///|
test "scratch scalable counting remove count roundtrip" {
  let key_count = 10
  for round = 1; round <= 120; round = round + 1 {
    let capacity = round % 5 + 1
    let rate = if round % 7 == 0 { 1.0e-8 } else { 0.5 }
    let left = ScalableCountingBloomFilter::new(capacity, rate)
    let right = ScalableCountingBloomFilter::new(capacity, rate)
    let lm : Array[Int32] = Array::make(key_count, 0)
    let rm : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 7919 + 17
    let filters : Array[ScalableCountingBloomFilter] = [left, right]
    for step = 0; step < 300; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let which = seed % 2
      let filter = filters[which]
      let model = if which == 0 { lm } else { rm }
      let key = seed / 11 % key_count
      let action = seed / 29 % 7
      if action == 0 {
        filter.insert(key)
        model[key] = model[key] + 1
      } else if action == 1 {
        let before = filter.count()
        if filter.remove(key) {
          if filter.count() != before - 1 {
            println("remove delta round=" + round.to_string() + " step=" + step.to_string() + " which=" + which.to_string() + " key=" + key.to_string() + " before=" + before.to_string() + " after=" + filter.count().to_string() + " count_of_before=" + model[key].to_string())
            panic()
          }
          if model[key] > 0 {
            model[key] = model[key] - 1
          }
        }
      } else if action == 2 {
        let added = filter.insert_if_absent(key)
        if added && model[key] == 0 {
          model[key] = 1
        }
      } else if action == 3 {
        ignore(filter.contains(key))
        ignore(filter.count_of(key))
      } else if action == 4 {
        let combined = filter.union(filters[1 - which])
        filters[which] = combined
        let other_model = if which == 0 { rm } else { lm }
        for k = 0; k < key_count; k = k + 1 {
          model[k] = if model[k] > other_model[k] { model[k] } else { other_model[k] }
        }
      } else if action == 5 {
        let common = filter.intersection(filters[1 - which])
        filters[which] = common
        let other_model = if which == 0 { rm } else { lm }
        for k = 0; k < key_count; k = k + 1 {
          model[k] = if model[k] < other_model[k] { model[k] } else { other_model[k] }
        }
      } else {
        ignore(filter.copy())
      }
      let current = filters[which]
      let bytes = current.to_bytes()
      let restored = ScalableCountingBloomFilter::from_bytes(bytes)
      if restored.to_bytes() != bytes {
        println("roundtrip mismatch round=" + round.to_string() + " step=" + step.to_string() + " which=" + which.to_string())
        panic()
      }
      if restored.count() != current.count() {
        println("roundtrip count mismatch round=" + round.to_string() + " step=" + step.to_string())
        panic()
      }
    }
  }
}
