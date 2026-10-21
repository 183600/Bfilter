///|
test "counting bloom remove leaves no residue after dense churn" {
  let filter = @src.CountingBloomFilter::with_size(64, 12)
  let keys : Array[String] = Array::makei(200, i => "churn-" + i.to_string())
  for round = 0; round < 5; round = round + 1 {
    for key in keys {
      filter.insert(key)
    }
  }
  for key in keys {
    for i = 0; i < 5; i = i + 1 {
      assert_true(filter.remove(key))
    }
  }
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "compact counting remove leaves no residue after dense churn" {
  let filter = @src.CompactCountingBloomFilter::with_size(512, 6)
  let keys : Array[String] = Array::makei(200, i => "churn-" + i.to_string())
  for key in keys {
    filter.insert(key)
  }
  for key in keys {
    assert_true(filter.remove(key))
  }
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}
