///|
test "extreme counting occurrence count deltas" {
  let configs : Array[(Int32, Int32)] = [
    (16, 1_100_000), (16, 2_000_000), (16, 20_000_000),
    (32, 2_100_000),
  ]
  for cfg in configs {
    let slots = cfg.0
    let hashes = cfg.1
    for mult = 1; mult <= 3; mult = mult + 1 {
      let f = @src.CountingBloomFilter::with_size(slots, hashes)
      for i = 0; i < mult; i = i + 1 {
        f.insert("key")
      }
      let before = f.count()
      let mut removed = 0
      while f.remove("key") {
        removed = removed + 1
        if f.count() != before - removed {
          println("counting count delta slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " before=" + before.to_string() + " removed=" + removed.to_string() + " after=" + f.count().to_string())
          panic()
        }
      }
      if removed > mult {
        println("counting removed too many slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " removed=" + removed.to_string())
        panic()
      }
      let bytes = f.to_bytes()
      let restored = @src.CountingBloomFilter::from_bytes(bytes)
      if restored.to_bytes() != bytes {
        println("counting roundtrip mismatch slots=" + slots.to_string() + " hashes=" + hashes.to_string())
        panic()
      }
    }
  }
}

///|
test "extreme compact occurrence count deltas" {
  let configs : Array[(Int32, Int32)] = [
    (16, 300), (16, 700), (16, 100000), (32, 3000),
  ]
  for cfg in configs {
    let slots = cfg.0
    let hashes = cfg.1
    for mult = 1; mult <= 20; mult = mult + 1 {
      let f = @src.CompactCountingBloomFilter::with_size(slots, hashes)
      for i = 0; i < mult; i = i + 1 {
        f.insert("key")
      }
      let before = f.count()
      let mut removed = 0
      while f.remove("key") {
        removed = removed + 1
        if f.count() != before - removed {
          println("compact count delta slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " before=" + before.to_string() + " removed=" + removed.to_string() + " after=" + f.count().to_string())
          panic()
        }
      }
      if removed > mult {
        println("compact removed too many slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " mult=" + mult.to_string() + " removed=" + removed.to_string())
        panic()
      }
      let bytes = f.to_bytes()
      let restored = @src.CompactCountingBloomFilter::from_bytes(bytes)
      if restored.to_bytes() != bytes {
        println("compact roundtrip mismatch slots=" + slots.to_string() + " hashes=" + hashes.to_string())
        panic()
      }
    }
  }
}
