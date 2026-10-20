///|
test "stress cuckoo union and subset across layouts" {
  let layouts : Array[(Int32, Int32)] = [
    (1, 1),
    (2, 2),
    (4, 1),
    (8, 2),
    (16, 4),
    (64, 3),
    (256, 8),
  ]
  for layout in layouts {
    let (bucket_count, bucket_size) = layout
    for round = 0; round < 10; round = round + 1 {
      let left = @src.CuckooFilter::with_size(bucket_count, bucket_size)
      let right = @src.CuckooFilter::with_size(bucket_count, bucket_size)
      let left_keys : Array[String] = []
      let right_keys : Array[String] = []
      for i = 0; i < 40; i = i + 1 {
        let key = "stress-" + round.to_string() + "-" + i.to_string()
        if i % 2 == 0 {
          if left.insert(key) {
            left_keys.push(key)
          }
        } else if right.insert(key) {
          right_keys.push(key)
        }
      }
      match left.union(right) {
        Some(combined) => {
          assert_eq(combined.count(), left.count() + right.count())
          assert_true(combined.contains_all(left_keys))
          assert_true(combined.contains_all(right_keys))
          assert_true(left.is_subset_of(combined))
          assert_true(right.is_subset_of(combined))
          for key in left_keys {
            assert_true(combined.remove(key))
          }
          for key in right_keys {
            assert_true(combined.remove(key))
          }
          assert_true(combined.is_empty())
        }
        None => {
          assert_true(left.contains_all(left_keys))
          assert_true(right.contains_all(right_keys))
        }
      }
    }
  }
}

///|
test "stress counting removals never lose remaining keys" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1),
    (32, 2),
    (64, 4),
    (128, 8),
    (48, 20),
  ]
  for layout in layouts {
    let (slot_count, hash_count) = layout
    for round = 0; round < 10; round = round + 1 {
      let filter = @src.CountingBloomFilter::with_size(slot_count, hash_count)
      let keys : Array[String] = []
      for i = 0; i < 60; i = i + 1 {
        let key = "counting-" + round.to_string() + "-" + i.to_string()
        filter.insert(key)
        keys.push(key)
      }
      for i = 0; i < keys.length(); i = i + 1 {
        if i % 3 == 0 {
          assert_true(filter.remove(keys[i]))
        }
      }
      for i = 0; i < keys.length(); i = i + 1 {
        if i % 3 != 0 {
          assert_true(filter.contains(keys[i]))
        }
      }
      assert_eq(filter.count(), 40)
    }
  }
}

///|
test "stress cuckoo operations preserve live keys and count" {
  for round = 0; round < 20; round = round + 1 {
    let filter = @src.CuckooFilter::with_size(16, 4)
    let key_count = 64
    let live : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 977 + 1
    for step = 0; step < 1000; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let action = seed / 31 % 3
      if action == 0 {
        if filter.insert(key) {
          live[key] = live[key] + 1
        }
      } else if action == 1 {
        if live[key] > 0 {
          assert_true(filter.remove(key))
          live[key] = live[key] - 1
        }
      } else if live[key] > 0 {
        assert_true(filter.contains(key))
      }
    }
    let mut expected = 0
    for key = 0; key < key_count; key = key + 1 {
      expected = expected + live[key]
      if live[key] > 0 {
        assert_true(filter.contains(key))
      }
    }
    assert_eq(filter.count(), expected)
  }
}

///|
test "stress counting operations preserve live keys and count" {
  for round = 0; round < 20; round = round + 1 {
    let filter = @src.CountingBloomFilter::with_size(256, 4)
    let key_count = 64
    let live : Array[Int32] = Array::make(key_count, 0)
    let mut seed = round * 613 + 7
    for step = 0; step < 1000; step = step + 1 {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
      let key = seed % key_count
      let action = seed / 31 % 3
      if action == 0 {
        filter.insert(key)
        live[key] = live[key] + 1
      } else if action == 1 {
        if live[key] > 0 {
          assert_true(filter.remove(key))
          live[key] = live[key] - 1
        }
      } else if live[key] > 0 {
        assert_true(filter.contains(key))
      }
    }
    let mut expected = 0
    for key = 0; key < key_count; key = key + 1 {
      expected = expected + live[key]
      if live[key] > 0 {
        assert_true(filter.contains(key))
      }
    }
    assert_eq(filter.count(), expected)
  }
}
