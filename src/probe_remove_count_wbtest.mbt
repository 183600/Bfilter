///|
fn probe_remove_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "probe successful removals decrement counting counts" {
  let configs : Array[(Int32, Int32)] = [
    (16,1),(16,2),(16,3),(16,7),(16,20),(16,65),(16,130),(16,700),
    (32,64),(32,65),(32,130),(32,700),(32,65535),(32,70000),(32,100000),
    (48,300),(48,70000),(64,200),(80,700),
  ]
  for cfg in configs {
    let slots = cfg.0
    let hashes = cfg.1
    for round = 1; round <= 80; round = round + 1 {
      let f = CountingBloomFilter::with_size(slots, hashes)
      let c = CompactCountingBloomFilter::with_size(slots, hashes)
      let keys = 24
      let mut seed = round * 7919 + slots * 31 + hashes
      for step = 0; step < 600; step = step + 1 {
        seed = probe_remove_seed(seed)
        let key = seed % keys
        let action = seed / 29 % 3
        if action == 0 {
          f.insert(key)
          c.insert(key)
        } else if action == 1 {
          let before = f.count()
          if f.remove(key) {
            if f.count() != before - 1 {
              println("counting count delta config=" + slots.to_string() + "x" + hashes.to_string() + " round=" + round.to_string() + " step=" + step.to_string() + " key=" + key.to_string() + " before=" + before.to_string() + " after=" + f.count().to_string())
              panic()
            }
          }
          let cbefore = c.count()
          if c.remove(key) {
            if c.count() != cbefore - 1 {
              println("compact count delta config=" + slots.to_string() + "x" + hashes.to_string() + " round=" + round.to_string() + " step=" + step.to_string() + " key=" + key.to_string() + " before=" + cbefore.to_string() + " after=" + c.count().to_string())
              panic()
            }
          }
        } else {
          ignore(f.insert_if_absent(key))
          ignore(c.insert_if_absent(key))
        }
      }
    }
  }
}
