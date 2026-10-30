///|
test "scratch counting single-key removal deltas" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1), (16, 2), (16, 3), (16, 5), (16, 7), (16, 8), (16, 9),
    (16, 15), (16, 16), (16, 17), (16, 32), (16, 33), (16, 63), (16, 64),
    (16, 65), (16, 100), (48, 1), (48, 2), (48, 3), (48, 5), (48, 63),
    (48, 64), (48, 65), (48, 127), (80, 7), (80, 64), (80, 65),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for mult = 1; mult <= 25; mult = mult + 1 {
      let f = CountingBloomFilter::with_size(slots, hashes)
      for i = 0; i < mult; i = i + 1 {
        f.insert("key")
      }
      let before = f.count()
      let mut removed = 0
      while f.remove("key") {
        removed = removed + 1
        if f.count() != before - removed {
          println("count delta slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " before=" + before.to_string() + " removed=" + removed.to_string() + " after=" + f.count().to_string()); panic()
        }
        if f.count_of("key") > mult - removed {
          println("count_of too high slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " removed=" + removed.to_string() + " count_of=" + f.count_of("key").to_string()); panic()
        }
        if removed < mult && f.count_of("key") > 0 && !f.contains("key") {
          println("false negative slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " removed=" + removed.to_string()); panic()
        }
      }
      if removed > mult {
        println("removed too many slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " removed=" + removed.to_string()); panic()
      }
    }
  }
}

///|
test "scratch compact single-key removal deltas" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1), (16, 2), (16, 3), (16, 5), (16, 7), (16, 8), (16, 9),
    (16, 15), (16, 16), (16, 17), (16, 32), (16, 33), (16, 63), (16, 64),
    (16, 65), (48, 1), (48, 2), (48, 3), (48, 5), (48, 15), (48, 63),
    (80, 7), (80, 64),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for mult = 1; mult <= 25; mult = mult + 1 {
      let f = CompactCountingBloomFilter::with_size(slots, hashes)
      for i = 0; i < mult; i = i + 1 {
        f.insert("key")
      }
      let before = f.count()
      let mut removed = 0
      while f.remove("key") {
        removed = removed + 1
        if f.count() != before - removed {
          println("compact count delta slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " before=" + before.to_string() + " removed=" + removed.to_string() + " after=" + f.count().to_string()); panic()
        }
        if removed < mult && f.count_of("key") > 0 && !f.contains("key") {
          println("compact false negative slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " removed=" + removed.to_string()); panic()
        }
      }
      if removed > mult {
        println("compact removed too many slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " removed=" + removed.to_string()); panic()
      }
    }
  }
}


///|
test "scratch saturated counting remove count deltas" {
  let configs : Array[(Int32, Int32)] = [
    (16, 65536), (16, 65537), (16, 70000), (16, 100000),
    (16, 1100000), (16, 2000000), (16, 20000000),
    (32, 70000), (32, 100000), (32, 2000000),
  ]
  for cfg in configs {
    let slots = cfg.0
    let hashes = cfg.1
    for round = 1; round <= 40; round = round + 1 {
      let f = CountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 104729 + slots * 17 + hashes
      for step = 0; step < 400; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 4
        let action = seed / 23 % 3
        if action == 0 {
          f.insert(key)
        } else if action == 1 {
          let before = f.count()
          if f.remove(key) && f.count() != before - 1 {
            println("saturated counting delta slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " round=" + round.to_string() + " step=" + step.to_string() + " before=" + before.to_string() + " after=" + f.count().to_string())
            panic()
          }
        } else {
          ignore(f.insert_if_absent(key))
        }
      }
    }
  }
}
