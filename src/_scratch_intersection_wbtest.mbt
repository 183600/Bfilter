///|
fn scratch_pairs(filter : CuckooFilter) -> Array[(Int32, Byte, Int32)] {
  let result : Array[(Int32, Byte, Int32)] = []
  let seen : Array[(Int32, Byte)] = []
  for bucket = 0; bucket < filter.bucket_count; bucket = bucket + 1 {
    for slot = 0; slot < filter.bucket_size; slot = slot + 1 {
      let fingerprint = filter.buckets[bucket * filter.bucket_size + slot]
      if fingerprint == b'\x00' {
        continue
      }
      let alternate = filter.alternate_index(bucket, fingerprint)
      let canonical = bucket.min(alternate)
      let mut found = false
      for item in seen {
        if item.0 == canonical && item.1 == fingerprint {
          found = true
          break
        }
      }
      if !found {
        seen.push((canonical, fingerprint))
        result.push((canonical, fingerprint, filter.pair_fingerprint_count(canonical, fingerprint)))
      }
    }
  }
  result
}

///|
test "scratch intersection count matches pair model" {
  let mut seed = 12345
  for round = 0; round < 500; round = round + 1 {
    let bc = 1 << (round % 5)
    let bs = 1 + round % 4
    let left = CuckooFilter::with_size(bc, bs)
    let right = CuckooFilter::with_size(bc, bs)
    for i = 0; i < bc * bs; i = i + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      if seed % 3 != 0 {
        left.buckets[i] = (seed % 255 + 1).to_byte()
        left.inserted = left.inserted + 1
      }
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      if seed % 3 != 0 {
        right.buckets[i] = (seed % 255 + 1).to_byte()
        right.inserted = right.inserted + 1
      }
    }
    let lp = scratch_pairs(left)
    let rp = scratch_pairs(right)
    let mut expected = 0
    for item in lp {
      let mut match_count = 0
      for other in rp {
        if other.0 == item.0 && other.1 == item.1 {
          match_count = other.2
        }
      }
      expected = expected + item.2.min(match_count)
    }
    let common = left.intersection(right)
    assert_eq(common.count(), expected)
    assert_true(common.is_subset_of(left))
    assert_true(common.is_subset_of(right))
  }
}
