///|
test "compact counting saturation churn keeps queries and bytes consistent" {
  let key_count = 8
  for round = 1; round <= 40; round = round + 1 {
    let filter = @src.CompactCountingBloomFilter::with_size(16, 4)
    let mut seed = round * 1103515245 + 12345
    let mut total_added = 0
    for step = 0; step < 400; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let action = seed / 31 % 5
      if action == 0 {
        filter.insert(key)
        total_added = total_added + 1
      } else if action == 1 {
        if filter.insert_if_absent(key) {
          total_added = total_added + 1
        }
      } else if action == 2 {
        let present = filter.contains(key)
        let before = filter.count()
        let removed = filter.remove(key)
        if !present {
          assert_false(removed)
          assert_eq(filter.count(), before)
        }
      } else if action == 3 {
        assert_eq(filter.contains(key), filter.count_of(key) > 0)
      } else {
        let bytes = filter.to_bytes()
        let restored = @src.CompactCountingBloomFilter::from_bytes(bytes)
        assert_eq(restored.to_bytes(), bytes)
        assert_eq(restored.count(), filter.count())
        assert_eq(
          restored.occupied_slot_count(),
          filter.occupied_slot_count(),
        )
        for k = 0; k < key_count; k = k + 1 {
          assert_eq(restored.count_of(k), filter.count_of(k))
        }
      }
      assert_true(filter.count() >= 0)
      assert_true(filter.count() <= total_added)
      assert_true(filter.occupied_slot_count() >= 0)
      assert_true(filter.occupied_slot_count() <= filter.slot_count())
    }
  }
}
