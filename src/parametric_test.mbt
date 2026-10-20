///|
test "parametric bloom configurations keep inserted keys" {
  let configurations : Array[(Int32, Double)] = [
    (1, 0.5),
    (10, 0.1),
    (100, 0.05),
    (1000, 0.01),
    (5000, 0.001),
  ]
  for configuration in configurations {
    let (expected_items, false_positive_rate) = configuration
    let filter = @src.BloomFilter::new(expected_items, false_positive_rate)
    assert_true(filter.bit_count() > 0)
    assert_true(filter.hash_count() >= 1)
    for i = 0; i < expected_items; i = i + 1 {
      filter.insert(i)
    }
    for i = 0; i < expected_items; i = i + 1 {
      assert_true(filter.contains(i))
    }
    assert_eq(filter.count(), expected_items)
  }
}

///|
test "parametric bloom false positive rate stays near target" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  for i = 0; i < 1000; i = i + 1 {
    filter.insert("present-" + i.to_string())
  }
  let mut false_positives = 0
  for i = 0; i < 5000; i = i + 1 {
    if filter.contains("absent-" + i.to_string()) {
      false_positives = false_positives + 1
    }
  }
  assert_true(false_positives.to_double() / 5000.0 < 0.03)
}

///|
test "parametric bloom explicit sizes never lose inserted keys" {
  let sizes : Array[(Int32, Int32)] = [
    (1, 1),
    (8, 2),
    (64, 3),
    (127, 4),
    (1024, 7),
  ]
  for configuration in sizes {
    let (bit_count, hash_count) = configuration
    let filter = @src.BloomFilter::with_size(bit_count, hash_count)
    let keys = ["alpha", "beta", "gamma"]
    filter.insert_all(keys)
    filter.insert(7)
    filter.insert(99)
    assert_true(filter.contains_all(keys))
    assert_true(filter.contains(7))
    assert_true(filter.contains(99))
    assert_eq(filter.count(), keys.length() + 2)
  }
}

///|
test "parametric counting configurations support deletion" {
  let configurations : Array[(Int32, Int32)] = [
    (16, 1),
    (64, 2),
    (128, 3),
    (1024, 5),
  ]
  for configuration in configurations {
    let (slot_count, hash_count) = configuration
    let filter = @src.CountingBloomFilter::with_size(slot_count, hash_count)
    let keys = ["a", "b", "c", "d", "e", "f", "g", "h"]
    filter.insert_all(keys)
    assert_true(filter.contains_all(keys))
    for key in keys {
      assert_true(filter.remove(key))
    }
    assert_true(filter.is_empty())
    for key in keys {
      assert_false(filter.contains(key))
    }
  }
}

///|
test "counting filter partial deletion keeps remaining keys" {
  let filter = @src.CountingBloomFilter::with_size(4096, 4)
  let keys = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta"]
  filter.insert_all(keys)
  for i = 0; i < keys.length(); i = i + 2 {
    assert_true(filter.remove(keys[i]))
  }
  for i = 0; i < keys.length(); i = i + 2 {
    assert_false(filter.contains(keys[i]))
  }
  for i = 1; i < keys.length(); i = i + 2 {
    assert_true(filter.contains(keys[i]))
  }
  assert_eq(filter.count(), keys.length() / 2)
}

///|
test "parametric cuckoo configurations preserve successful inserts" {
  let configurations : Array[(Int32, Int32)] = [
    (1, 1),
    (2, 2),
    (8, 4),
    (64, 3),
    (256, 8),
  ]
  for configuration in configurations {
    let (bucket_count, bucket_size) = configuration
    let filter = @src.CuckooFilter::with_size(bucket_count, bucket_size)
    let keys = ["k0", "k1", "k2", "k3", "k4", "k5", "k6", "k7"]
    let inserted : Array[String] = []
    for key in keys {
      if filter.insert(key) {
        inserted.push(key)
      }
    }
    assert_eq(filter.count(), inserted.length())
    for key in inserted {
      assert_true(filter.contains(key))
    }
    for key in inserted {
      assert_true(filter.remove(key))
    }
    assert_true(filter.is_empty())
    for key in inserted {
      assert_false(filter.contains(key))
    }
  }
}

///|
test "parametric cuckoo insert_all reports partial failure" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  let keys = ["a", "b", "c", "d"]
  assert_false(filter.insert_all(keys))
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("a"))
  assert_false(filter.contains("b"))
}

///|
test "parametric concurrent filter handles duplicate inserts" {
  let filter = @src.ConcurrentBloomFilter::with_size(256, 3)
  for i = 0; i < 10; i = i + 1 {
    filter.insert("duplicate")
  }
  assert_eq(filter.count(), 10)
  assert_true(filter.contains("duplicate"))
  filter.clear()
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("duplicate"))
}
