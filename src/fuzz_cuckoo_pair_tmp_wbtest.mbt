///|
test "fuzz cuckoo intersection exact pair multiplicities" {
  let layouts = [(1, 1), (1, 2), (2, 1), (2, 2), (4, 1), (4, 2), (4, 3), (8, 4)]
  for round = 1; round <= 60; round = round + 1 {
    for layout in layouts {
      let (bucket_count, bucket_size) = layout
      let left = CuckooFilter::with_size(bucket_count, bucket_size)
      let right = CuckooFilter::with_size(bucket_count, bucket_size)
      let capacity = bucket_count * bucket_size
      let mut seed = round * 977 + bucket_count * 5 + bucket_size
      for step = 0; step < capacity * 12; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % (capacity * 3)
        let action = seed / 19 % 4
        if action == 0 {
          ignore(left.insert(key))
        } else if action == 1 {
          ignore(right.insert(key))
        } else if action == 2 {
          ignore(left.insert(key))
          ignore(right.insert(key))
        } else {
          ignore(left.remove(key))
          ignore(right.remove(key))
        }
      }
      let common = left.intersection(right)
      let visited : @hashmap.HashMap[(Int32, Byte), Unit] = @hashmap.HashMap([])
      let mut expected = 0
      for bucket = 0; bucket < left.bucket_count; bucket = bucket + 1 {
        let base = bucket * left.bucket_size
        for slot = 0; slot < left.bucket_size; slot = slot + 1 {
          let fingerprint = left.buckets[base + slot]
          if fingerprint == b'\x00' {
            continue
          }
          let alternate = left.alternate_index(bucket, fingerprint)
          let canonical = bucket.min(alternate)
          let pair = (canonical, fingerprint)
          if visited.contains(pair) {
            continue
          }
          visited.set(pair, ())
          let keep = left
            .pair_fingerprint_count(canonical, fingerprint)
            .min(right.pair_fingerprint_count(canonical, fingerprint))
          expected = expected + keep
          let actual = common.pair_fingerprint_count(canonical, fingerprint)
          if actual != keep {
            println("mismatch round=" + round.to_string() + " layout=" + layout.0.to_string() + "x" + layout.1.to_string() + " bucket=" + canonical.to_string() + " fp=" + fingerprint.to_string() + " keep=" + keep.to_string() + " actual=" + actual.to_string())
            panic()
          }
        }
      }
      assert_eq(common.count(), expected)
    }
  }
}
