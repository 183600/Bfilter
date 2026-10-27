///|
fn fuzz_cuckoo_pairs_subset(left : CuckooFilter, right : CuckooFilter) -> Bool {
  if left.count() == 0 {
    return true
  }
  if left.count() > right.count() {
    return false
  }
  let visited : @hashmap.HashMap[(Int32, Byte), Unit] = @hashmap.HashMap([])
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
      if left.pair_fingerprint_count(canonical, fingerprint) >
        right.pair_fingerprint_count(canonical, fingerprint) {
        return false
      }
    }
  }
  true
}

///|
fn fuzz_cuckoo_pairs_disjoint(left : CuckooFilter, right : CuckooFilter) -> Bool {
  if left.count() == 0 || right.count() == 0 {
    return true
  }
  let visited : @hashmap.HashMap[(Int32, Byte), Unit] = @hashmap.HashMap([])
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
      if right.pair_fingerprint_count(canonical, fingerprint) > 0 {
        return false
      }
    }
  }
  true
}

///|
test "fuzz cuckoo subset and disjoint checks match pair model" {
  let layouts = [(1, 1), (1, 2), (2, 1), (2, 2), (4, 1), (4, 2), (4, 3), (8, 4)]
  for round = 1; round <= 80; round = round + 1 {
    for layout in layouts {
      let (bucket_count, bucket_size) = layout
      let left = CuckooFilter::with_size(bucket_count, bucket_size)
      let right = CuckooFilter::with_size(bucket_count, bucket_size)
      let capacity = bucket_count * bucket_size
      let mut seed = round * 1237 + bucket_count * 7 + bucket_size
      for step = 0; step < capacity * 10; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % (capacity * 3)
        let action = seed / 23 % 4
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
      let subset = fuzz_cuckoo_pairs_subset(left, right)
      if left.is_subset_of(right) != subset {
        println("subset mismatch round=" + round.to_string() + " layout=" + layout.0.to_string() + "x" + layout.1.to_string() + " actual=" + left.is_subset_of(right).to_string() + " expected=" + subset.to_string())
        panic()
      }
      let disjoint = fuzz_cuckoo_pairs_disjoint(left, right)
      if left.is_disjoint_from(right) != disjoint {
        println("disjoint mismatch round=" + round.to_string() + " layout=" + layout.0.to_string() + "x" + layout.1.to_string() + " actual=" + left.is_disjoint_from(right).to_string() + " expected=" + disjoint.to_string())
        panic()
      }
    }
  }
}
