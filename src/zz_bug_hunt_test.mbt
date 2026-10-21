///|
test "zz counting serialization survives saturated churn" {
  for round = 1; round <= 20; round = round + 1 {
    let filter = @src.CountingBloomFilter::with_size(16, 7)
    let mut seed = round
    for step = 0; step < 400; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 6
      let action = seed / 31 % 3
      if action == 0 {
        filter.insert(key)
      } else if action == 1 {
        ignore(filter.remove(key))
      } else {
        let bytes = filter.to_bytes()
        let restored = @src.CountingBloomFilter::from_bytes(bytes)
        assert_eq(restored.count(), filter.count())
        assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
      }
    }
  }
}

///|
test "zz compact counting serialization survives saturated churn" {
  for round = 1; round <= 20; round = round + 1 {
    let filter = @src.CompactCountingBloomFilter::with_size(16, 7)
    let mut seed = round
    for step = 0; step < 400; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 6
      let action = seed / 31 % 3
      if action == 0 {
        filter.insert(key)
      } else if action == 1 {
        ignore(filter.remove(key))
      } else {
        let bytes = filter.to_bytes()
        let restored = @src.CompactCountingBloomFilter::from_bytes(bytes)
        assert_eq(restored.count(), filter.count())
        assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
      }
    }
  }
}

///|
test "zz scalable serialization survives growth and merges" {
  for round = 1; round <= 10; round = round + 1 {
    let left = @src.ScalableBloomFilter::new(3, 0.05)
    let right = @src.ScalableBloomFilter::new(3, 0.05)
    let mut seed = round
    for step = 0; step < 120; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = "k-" + (seed % 50).to_string()
      if step % 3 == 0 {
        right.insert(key)
      } else {
        left.insert(key)
      }
      if step % 17 == 0 {
        left.merge(right)
        let restored = @src.ScalableBloomFilter::from_bytes(left.to_bytes())
        assert_eq(restored.count(), left.count())
        assert_eq(restored.slice_count(), left.slice_count())
        assert_eq(restored.bit_count(), left.bit_count())
      }
    }
  }
}

///|
test "zz blocked serialization survives churn" {
  for round = 1; round <= 20; round = round + 1 {
    let filter = @src.BlockedBloomFilter::with_size(4096, 4)
    let mut seed = round
    for step = 0; step < 300; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % 100
      if step % 5 == 0 {
        let restored = @src.BlockedBloomFilter::from_bytes(filter.to_bytes())
        assert_eq(restored.count(), filter.count())
        assert_eq(restored.set_bit_count(), filter.set_bit_count())
      } else {
        filter.insert(key)
      }
    }
  }
}
