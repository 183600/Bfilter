///|
fn test_fingerprint_with_delta(delta : UInt64, excluded : Array[Byte]) -> Byte {
  for i = 1; i < 256; i = i + 1 {
    let fingerprint = i.to_uint64().to_byte()
    if (fingerprint_hash(fingerprint) & 3UL) == delta &&
      !excluded.contains(fingerprint) {
      return fingerprint
    }
  }
  abort("no fingerprint with the requested alternate bucket")
}

///|
test "cuckoo augmenting path moves fingerprints to the empty bucket" {
  let filter = CuckooFilter::with_size(4, 1)
  let first = test_fingerprint_with_delta(1UL, [])
  let second = test_fingerprint_with_delta(3UL, [first])
  let third = test_fingerprint_with_delta(1UL, [first, second])
  let inserted = test_fingerprint_with_delta(0UL, [first, second, third])
  filter.buckets[0] = first
  filter.buckets[1] = second
  filter.buckets[2] = third
  filter.inserted = 3
  assert_true(filter.insert_fingerprint_bfs(0, inserted))
  assert_eq(filter.count(), 4)
  assert_eq(filter.buckets[0], inserted)
  assert_eq(filter.buckets[1], first)
  assert_eq(filter.buckets[2], second)
  assert_eq(filter.buckets[3], third)
  assert_eq(filter.alternate_index(1, first), 0)
  assert_eq(filter.alternate_index(2, second), 1)
  assert_eq(filter.alternate_index(3, third), 2)
  assert_false(filter.insert_fingerprint_bfs(0, inserted))
}

///|
test "cuckoo insertion falls back to an augmenting path" {
  let filter = CuckooFilter::with_size(4, 1)
  let first = test_fingerprint_with_delta(1UL, [])
  let second = test_fingerprint_with_delta(3UL, [first])
  let third = test_fingerprint_with_delta(1UL, [first, second])
  let inserted = test_fingerprint_with_delta(0UL, [first, second, third])
  filter.buckets[0] = first
  filter.buckets[1] = second
  filter.buckets[2] = third
  filter.inserted = 3
  assert_true(filter.insert_fingerprint(0, inserted))
  assert_eq(filter.count(), 4)
  assert_eq(filter.buckets[0], inserted)
  assert_eq(filter.buckets[1], first)
  assert_eq(filter.buckets[2], second)
  assert_eq(filter.buckets[3], third)
}
