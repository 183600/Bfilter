///|
fn cuckoo_intersection_expected_count(
  left : CuckooFilter,
  right : CuckooFilter,
) -> Int32 {
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
      expected = expected +
        left
        .pair_fingerprint_count(canonical, fingerprint)
        .min(right.pair_fingerprint_count(canonical, fingerprint))
    }
  }
  expected
}

///|
test "randomized cuckoo intersections keep smaller pair multiplicities" {
  let layouts = [
    (4, 1),
    (8, 1),
    (16, 1),
    (16, 2),
    (32, 2),
    (8, 4),
    (16, 4),
    (32, 4),
  ]
  for round = 1; round <= 40; round = round + 1 {
    for layout in layouts {
      let (bucket_count, bucket_size) = layout
      let left = CuckooFilter::with_size(bucket_count, bucket_size)
      let right = CuckooFilter::with_size(bucket_count, bucket_size)
      let capacity = bucket_count * bucket_size
      let mut seed = round * 617 + bucket_count * 3 + bucket_size
      for step = 0; step < capacity * 8; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % (capacity * 2)
        let action = seed / 17 % 3
        if action == 0 {
          ignore(left.insert(key))
        } else if action == 1 {
          ignore(right.insert(key))
        } else {
          ignore(left.insert(key))
          ignore(right.insert(key))
        }
      }
      let expected = cuckoo_intersection_expected_count(left, right)
      let common = left.intersection(right)
      assert_eq(common.count(), expected)
      assert_true(common.is_subset_of(left))
      assert_true(common.is_subset_of(right))
      let restored = CuckooFilter::from_bytes(common.to_bytes())
      assert_eq(restored.count(), common.count())
      assert_eq(restored.to_bytes(), common.to_bytes())
    }
  }
}
