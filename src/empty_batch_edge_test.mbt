///|
/// Empty batches are no-ops and never touch the backing storage. These tests
/// guard that contract for every filter type on both empty and non-empty
/// filters, including the direct (non-concurrent) constructors.
///|

///|
test "counting bloom filter empty batch queries on an empty filter" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  filter.insert_all(empty)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "counting bloom filter empty batch queries on a non-empty filter" {
  let filter = @src.CountingBloomFilter::with_size(1024, 4)
  filter.insert_all(["alpha", "beta"])
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_eq(filter.count(), 2)
  assert_true(filter.remove_all(empty))
  assert_eq(filter.count(), 2)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains("beta"))
}

///|
test "compact counting bloom filter empty batch queries on an empty filter" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  filter.insert_all(empty)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.occupied_slot_count(), 0)
}

///|
test "compact counting bloom filter empty batch queries on a non-empty filter" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  filter.insert_all(["alpha", "beta"])
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_eq(filter.count(), 2)
  assert_true(filter.remove_all(empty))
  assert_eq(filter.count(), 2)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains("beta"))
}

///|
test "scalable bloom filter empty batch queries on an empty filter" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  filter.insert_all(empty)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_eq(filter.count(), 0)
  assert_eq(filter.slice_count(), 1)
}

///|
test "scalable bloom filter empty batch queries on a non-empty filter" {
  let filter = @src.ScalableBloomFilter::new(100, 0.01)
  filter.insert("alpha")
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("alpha"))
}

///|
test "scalable counting bloom filter empty batch queries on an empty filter" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  filter.insert_all(empty)
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.tracked_key_count(), 0)
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_true(filter.remove_all(empty))
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.tracked_key_count(), 0)
}

///|
test "scalable counting bloom filter empty batch queries on a non-empty filter" {
  let filter = @src.ScalableCountingBloomFilter::new(100, 0.01)
  filter.insert_all(["alpha", "beta"])
  let empty : Array[String] = []
  assert_true(filter.contains_all(empty))
  assert_false(filter.contains_any(empty))
  assert_eq(filter.insert_all_if_absent(empty), 0)
  assert_eq(filter.count(), 2)
  assert_true(filter.remove_all(empty))
  assert_eq(filter.count(), 2)
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains("beta"))
  assert_eq(filter.tracked_key_count(), 2)
}
