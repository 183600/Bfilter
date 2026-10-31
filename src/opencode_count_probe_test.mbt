///|
test "opencode counting remove count delta fuzz" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1), (16, 7), (16, 65), (16, 70000), (32, 17), (32, 65), (32, 100000), (48, 65), (48, 70000), (80, 130), (96, 200000),
    (256, 70000),
  ]
  for layout in layouts {
    let (slots, hashes) = layout
    for round = 1; round <= 8; round = round + 1 {
      let f = CountingBloomFilter::with_size(slots, hashes)
      let mut seed = round * 104729 + slots * 31 + hashes * 17
      for step = 0; step < 200; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 7
        let action = seed / 37 % 4
        if action == 0 {
          let before = f.count()
          f.insert(key)
          assert_eq(f.count(), before + 1)
        } else if action == 1 {
          let before = f.count()
          let removed = f.remove(key)
          if removed && f.count() != before - 1 {
            println("delta mismatch slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " round=" + round.to_string() + " step=" + step.to_string() + " key=" + key.to_string() + " before=" + before.to_string() + " after=" + f.count().to_string())
            panic()
          }
        } else if action == 2 {
          let before = f.count()
          let added = f.insert_if_absent(key)
          if added {
            assert_eq(f.count(), before + 1)
          } else {
            assert_eq(f.count(), before)
          }
        } else {
          ignore(f.contains(key))
          ignore(f.count_of(key))
        }
      }
    }
  }
}
