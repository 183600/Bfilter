///|
test "failed cuckoo insertion restores buckets and eviction state" {
  let filter = CuckooFilter::with_size(4, 1)
  // Find a key whose two candidate buckets differ. Fill both with the key's
  // fingerprint so eviction and the augmenting-path search can only cycle
  // inside that pair; the other two buckets stay free but unreachable.
  let mut key = 0
  let mut found = false
  while !found && key < 10_000 {
    let (index1, fingerprint) = filter.key_info(key)
    let index2 = filter.alternate_index(index1, fingerprint)
    if index2 != index1 {
      filter.buckets[index1] = fingerprint
      filter.buckets[index2] = fingerprint
      filter.inserted = 2
      filter.random_state = 0x9E3779B97F4A7C15UL
      let expected = filter.to_bytes()
      assert_false(filter.insert(key))
      assert_eq(filter.count(), 2)
      assert_eq(filter.random_state, 0x9E3779B97F4A7C15UL)
      assert_eq(filter.to_bytes(), expected)
      assert_true(filter.contains(key))
      found = true
    }
    key = key + 1
  }
  assert_true(found)
}
