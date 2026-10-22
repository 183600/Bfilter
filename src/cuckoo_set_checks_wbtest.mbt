///|
test "cuckoo set checks handle duplicate fingerprints in one bucket" {
  let filter = CuckooFilter::with_size(4, 4)
  let mut chosen = b'\x00'
  for value = 1; value < 256; value = value + 1 {
    let fingerprint = value.to_byte()
    if filter.alternate_index(0, fingerprint) != 0 {
      chosen = fingerprint
      break
    }
  }
  assert_true(chosen != b'\x00')
  let alternate = filter.alternate_index(0, chosen)
  filter.buckets[0] = chosen
  filter.buckets[1] = chosen
  filter.buckets[alternate * filter.bucket_size] = chosen
  filter.inserted = 3
  let mirror = filter.copy()
  assert_true(filter.is_subset_of(mirror))
  assert_true(mirror.is_subset_of(filter))
  assert_false(filter.is_disjoint_from(mirror))
  assert_false(mirror.is_disjoint_from(filter))
  let common = filter.intersection(mirror)
  assert_eq(common.count(), 3)
  assert_eq(common.is_subset_of(filter), true)
  assert_eq(common.is_subset_of(mirror), true)
}

///|
test "cuckoo merge into an empty receiver copies the source state" {
  let source = CuckooFilter::with_size(8, 4)
  let keys = ["alpha", "beta", "gamma", "delta", "epsilon"]
  for key in keys {
    assert_true(source.insert(key))
  }
  let target = CuckooFilter::with_size(8, 4)
  target.random_state = 0x13579BDF2468ACE0UL
  assert_true(target.merge(source))
  assert_eq(target.to_bytes(), source.to_bytes())
  assert_true(target.is_subset_of(source))
  assert_true(source.is_subset_of(target))
  assert_true(source.remove("alpha"))
  assert_true(target.contains("alpha"))
  assert_eq(target.count(), keys.length())
}

///|
test "cuckoo fingerprint insertion rejects a full filter directly" {
  let filter = CuckooFilter::with_size(1, 1)
  filter.buckets[0] = b'\x05'
  filter.inserted = 1
  assert_false(filter.insert_fingerprint(0, b'\x06'))
  assert_eq(filter.inserted, 1)
  assert_eq(filter.buckets[0], b'\x05')
}

