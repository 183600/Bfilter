///|
test "scratch cuckoo restore can keep filling" {
  for round = 1; round <= 50; round = round + 1 {
    let filter = @src.CuckooFilter::with_size(16, 4)
    let keys : Array[String] = []
    let mut seed = round
    for i = 0; i < 40; i = i + 1 {
      let key = "restore-" + round.to_string() + "-" + i.to_string()
      if filter.insert(key) {
        keys.push(key)
      }
    }
    let restored = @src.CuckooFilter::from_bytes(filter.to_bytes())
    for k in keys {
      assert_true(restored.contains(k))
    }
    for i = 40; i < 200; i = i + 1 {
      let key = "restore-" + round.to_string() + "-" + i.to_string()
      if restored.insert(key) {
        keys.push(key)
      }
    }
    assert_eq(restored.count(), keys.length())
    for k in keys {
      assert_true(restored.contains(k))
    }
    assert_true(restored.count() <= restored.capacity())
    seed = seed + 1
  }
}

///|
test "scratch scalable keeps keys across restore and growth" {
  for round = 1; round <= 20; round = round + 1 {
    let filter = @src.ScalableBloomFilter::new(3, 0.05)
    let keys : Array[String] = []
    for i = 0; i < 100; i = i + 1 {
      let key = "scale-" + round.to_string() + "-" + i.to_string()
      filter.insert(key)
      keys.push(key)
      if i % 17 == 0 {
        let restored = @src.ScalableBloomFilter::from_bytes(filter.to_bytes())
        assert_eq(restored.count(), filter.count())
        assert_eq(restored.slice_count(), filter.slice_count())
        for k in keys {
          assert_true(restored.contains(k))
        }
        let before = restored.count()
        restored.insert("extra-" + i.to_string())
        assert_eq(restored.count(), before + 1)
        assert_true(restored.contains("extra-" + i.to_string()))
      }
    }
    for k in keys {
      assert_true(filter.contains(k))
    }
  }
}

///|
test "scratch cuckoo intersection count and members" {
  for round = 1; round <= 50; round = round + 1 {
    let left = @src.CuckooFilter::with_size(32, 4)
    let right = @src.CuckooFilter::with_size(32, 4)
    for i = 0; i < 60; i = i + 1 {
      let left_key = "left-" + round.to_string() + "-" + i.to_string()
      let right_key = "right-" + round.to_string() + "-" + i.to_string()
      assert_true(left.insert(left_key))
      assert_true(right.insert(right_key))
      if i % 3 == 0 {
        assert_true(left.insert(right_key))
        assert_true(right.insert(left_key))
      }
    }
    let common = left.intersection(right)
    for i = 0; i < 60; i = i + 3 {
      let key = "left-" + round.to_string() + "-" + i.to_string()
      assert_true(common.contains(key))
    }
    assert_true(common.count() <= left.count())
    assert_true(common.count() <= right.count())
    assert_true(common.is_subset_of(left))
    assert_true(common.is_subset_of(right))
  }
}
