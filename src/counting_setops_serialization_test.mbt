///|
test "randomized counting serialization of set op results" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1), (16, 4), (16, 20), (48, 20), (16, 300), (48, 720), (256, 2),
  ]
  for layout in layouts {
    let (slots, k) = layout
    for round = 1; round <= 30; round = round + 1 {
      let left = @src.CountingBloomFilter::with_size(slots, k)
      let right = @src.CountingBloomFilter::with_size(slots, k)
      let mut seed = round * 131 + 17
      for step = 0; step < 300; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 20
        let action = seed / 31 % 3
        if action == 0 {
          left.insert(key)
        } else if action == 1 {
          right.insert(key)
        } else {
          let c = left.union(right)
          let restored = @src.CountingBloomFilter::from_bytes(c.to_bytes())
          assert_eq(restored.count(), c.count())
        }
      }
      let u = left.union(right)
      assert_eq(@src.CountingBloomFilter::from_bytes(u.to_bytes()).count(), u.count())
      let i = left.intersection(right)
      assert_eq(@src.CountingBloomFilter::from_bytes(i.to_bytes()).count(), i.count())
      let m = left.copy()
      m.merge(right)
      assert_eq(@src.CountingBloomFilter::from_bytes(m.to_bytes()).count(), m.count())
    }
  }
}

///|
test "randomized compact counting serialization of set op results" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1), (16, 4), (16, 20), (48, 20), (16, 300), (48, 720), (256, 2),
  ]
  for layout in layouts {
    let (slots, k) = layout
    for round = 1; round <= 30; round = round + 1 {
      let left = @src.CompactCountingBloomFilter::with_size(slots, k)
      let right = @src.CompactCountingBloomFilter::with_size(slots, k)
      let mut seed = round * 131 + 17
      for step = 0; step < 300; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 20
        let action = seed / 31 % 3
        if action == 0 {
          left.insert(key)
        } else if action == 1 {
          right.insert(key)
        } else {
          let c = left.union(right)
          let restored = @src.CompactCountingBloomFilter::from_bytes(c.to_bytes())
          assert_eq(restored.count(), c.count())
        }
      }
      let u = left.union(right)
      assert_eq(@src.CompactCountingBloomFilter::from_bytes(u.to_bytes()).count(), u.count())
      let i = left.intersection(right)
      assert_eq(@src.CompactCountingBloomFilter::from_bytes(i.to_bytes()).count(), i.count())
      let m = left.copy()
      m.merge(right)
      assert_eq(@src.CompactCountingBloomFilter::from_bytes(m.to_bytes()).count(), m.count())
    }
  }
}
