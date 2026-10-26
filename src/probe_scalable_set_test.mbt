///|
fn probe_next(seed : Int32) -> Int32 {
  (seed * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
fn probe_build(seed : Int32, start_key : Int32, key_count : Int32, inserts : Int32) -> (@src.ScalableCountingBloomFilter, Array[Int32]) {
  let f = @src.ScalableCountingBloomFilter::new(2, 0.01)
  let live : Array[Int32] = Array::make(key_count, 0)
  let mut s = seed
  for i = 0; i < inserts; i = i + 1 {
    s = probe_next(s)
    let key = (start_key + s % key_count) % key_count
    f.insert(key)
    live[key] = live[key] + 1
  }
  (f, live)
}

///|
test "probe scalable counting set operations serialize exactly" {
  let key_count = 40
  for round = 1; round <= 30; round = round + 1 {
    let (left, live_left) = probe_build(round * 17 + 3, 0, key_count, 50 + round)
    let (right, live_right) = probe_build(round * 29 + 7, 10, key_count, 50 + round * 2)
    // remove some live keys from either input
    for key = 0; key < key_count; key = key + 1 {
      if (key + round) % 5 == 0 {
        let mut n = live_left[key].min(1)
        while n > 0 && left.remove(key) {
          live_left[key] = live_left[key] - 1
          n = n - 1
        }
      }
      if (key + round) % 7 == 0 {
        let mut n = live_right[key].min(2)
        while n > 0 && right.remove(key) {
          live_right[key] = live_right[key] - 1
          n = n - 1
        }
      }
    }
    let combined = left.union(right)
    let restored_union = @src.ScalableCountingBloomFilter::from_bytes(combined.to_bytes())
    assert_eq(restored_union.count(), combined.count())
    assert_eq(restored_union.tracked_key_count(), combined.tracked_key_count())
    for key = 0; key < key_count; key = key + 1 {
      assert_eq(restored_union.count_of(key), combined.count_of(key))
      if live_left[key] > 0 || live_right[key] > 0 {
        assert_true(combined.contains(key))
        assert_true(restored_union.contains(key))
        assert_true(combined.count_of(key) >= live_left[key].max(live_right[key]))
      }
    }
    let common = left.intersection(right)
    let restored_common = @src.ScalableCountingBloomFilter::from_bytes(common.to_bytes())
    assert_eq(restored_common.count(), common.count())
    assert_eq(restored_common.tracked_key_count(), common.tracked_key_count())
    for key = 0; key < key_count; key = key + 1 {
      assert_eq(restored_common.count_of(key), common.count_of(key))
      if live_left[key] > 0 && live_right[key] > 0 {
        assert_true(common.contains(key))
        assert_true(restored_common.contains(key))
        assert_eq(common.count_of(key), live_left[key].min(live_right[key]))
      } else {
        assert_eq(common.count_of(key), 0)
      }
    }
    assert_true(common.is_subset_of(left))
    assert_true(common.is_subset_of(right))
    assert_true(left.is_subset_of(combined))
    assert_true(right.is_subset_of(combined))
  }
}
