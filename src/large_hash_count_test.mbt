///|
test "counting filters handle large hash counts without duplicate residue" {
  let keys : Array[Int32] = [3, 7, 11, 19, 23, 29, 31, 37]
  let counting = @src.CountingBloomFilter::with_size(4096, 300)
  let compact = @src.CompactCountingBloomFilter::with_size(4096, 300)
  for key in keys {
    counting.insert(key)
    counting.insert(key)
    compact.insert(key)
    compact.insert(key)
  }
  for key in keys {
    assert_true(counting.remove(key))
    assert_true(counting.remove(key))
    assert_true(compact.remove(key))
    assert_true(compact.remove(key))
  }
  assert_eq(counting.count(), 0)
  assert_eq(counting.occupied_slot_count(), 0)
  assert_eq(compact.count(), 0)
  assert_eq(compact.occupied_slot_count(), 0)
  let restored_counting = @src.CountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  let restored_compact = @src.CompactCountingBloomFilter::from_bytes(
    compact.to_bytes(),
  )
  assert_eq(restored_counting.count(), 0)
  assert_eq(restored_counting.occupied_slot_count(), 0)
  assert_eq(restored_compact.count(), 0)
  assert_eq(restored_compact.occupied_slot_count(), 0)
}
