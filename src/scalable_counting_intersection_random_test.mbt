///|
test "randomized scalable counting intersections stay removable and serializable" {
  for round = 1; round <= 20; round = round + 1 {
    let left = @src.ScalableCountingBloomFilter::new(4, 0.05)
    let right = @src.ScalableCountingBloomFilter::new(4, 0.05)
    let key_count = 20
    let left_live : Array[Int32] = Array::make(key_count, 0)
    let right_live : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 7919 + 3
    for step = 0; step < 160; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      if seed / 31 % 2 == 0 {
        left.insert(key)
        left_live[key] = left_live[key] + 1
      } else {
        right.insert(key)
        right_live[key] = right_live[key] + 1
      }
    }
    let common = left.intersection(right)
    for key = 0; key < key_count; key = key + 1 {
      let expected = left_live[key].min(right_live[key])
      assert_eq(common.count_of(key), expected)
    }
    let restored = @src.ScalableCountingBloomFilter::from_bytes(common.to_bytes())
    assert_eq(restored.count(), common.count())
    assert_eq(restored.tracked_key_count(), common.tracked_key_count())
    for key = 0; key < key_count; key = key + 1 {
      let occurrences = common.count_of(key)
      for i = 0; i < occurrences; i = i + 1 {
        assert_true(common.remove(key))
      }
      assert_eq(common.count_of(key), 0)
    }
    assert_eq(common.count(), 0)
    assert_eq(common.tracked_key_count(), 0)
    assert_eq(common.occupied_slot_count(), 0L)
  }
}
