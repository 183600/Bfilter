///|
test "guide quick start bloom filter" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  filter.insert("alpha")
  filter.insert("beta")
  assert_true(filter.contains("alpha"))
  assert_false(filter.contains("gamma"))
}

///|
test "guide bloom filter sized workload meets target rate" {
  let filter = @src.BloomFilter::new(10_000, 0.001)
  for i = 0; i < 10_000; i = i + 1 {
    filter.insert(i)
  }
  assert_true(filter.contains(123))
  assert_true(filter.false_positive_rate() < 0.01)
}

///|
test "guide bloom filter batch helpers and clear" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  let keys = ["red", "green", "blue"]
  filter.insert_all(keys)
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains_any(["missing", "red"]))
  filter.clear()
  assert_true(filter.is_empty())
}

///|
test "guide bloom filter insert_if_absent counts insertions" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  assert_true(filter.insert_if_absent("once"))
  assert_false(filter.insert_if_absent("once"))
  assert_eq(filter.count(), 1)
}

///|
test "guide bloom filter insert_all_if_absent counts additions" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  let keys = ["a", "b", "c"]
  assert_eq(filter.insert_all_if_absent(keys), 3)
  assert_eq(filter.insert_all_if_absent(keys), 0)
  assert_eq(filter.count(), 3)
}

///|
test "guide bloom filter set algebra" {
  let left = @src.BloomFilter::with_size(4096, 4)
  let right = @src.BloomFilter::with_size(4096, 4)
  left.insert("left")
  right.insert("right")
  let combined = left.union(right)
  assert_true(combined.contains("left"))
  assert_true(combined.contains("right"))
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  left.insert("shared")
  right.insert("shared")
  let common = left.intersection(right)
  assert_true(common.contains("shared"))
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
}

///|
test "guide bloom filter merge in place" {
  let left = @src.BloomFilter::with_size(4096, 4)
  let right = @src.BloomFilter::with_size(4096, 4)
  left.insert("left")
  right.insert("right")
  let combined = left.union(right)
  let target = @src.BloomFilter::with_size(4096, 4)
  target.insert("target")
  target.merge(combined)
  assert_true(target.contains("left"))
  assert_true(target.contains("target"))
}

///|
test "guide counting bloom filter removal round trip" {
  let filter = @src.CountingBloomFilter::new(1000, 0.01)
  filter.insert("task")
  filter.insert("task")
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("task"))
  assert_true(filter.contains("task"))
  assert_true(filter.remove("task"))
  assert_false(filter.contains("task"))
}

///|
test "guide counting bloom filter count_of tracks multiplicity" {
  let filter = @src.CountingBloomFilter::new(1000, 0.01)
  filter.insert("task")
  filter.insert("task")
  assert_eq(filter.count_of("task"), 2)
  assert_true(filter.remove("task"))
  assert_eq(filter.count_of("task"), 1)
}

///|
test "guide counting bloom filter insert_if_absent" {
  let filter = @src.CountingBloomFilter::new(1000, 0.01)
  assert_true(filter.insert_if_absent("once"))
  assert_false(filter.insert_if_absent("once"))
  assert_eq(filter.count(), 1)
  assert_true(filter.remove_all(["once"]))
  assert_true(filter.is_empty())
}

///|
test "guide counting bloom filter set algebra" {
  let left = @src.CountingBloomFilter::with_size(4096, 4)
  let right = @src.CountingBloomFilter::with_size(4096, 4)
  left.insert("left")
  right.insert("right")
  let combined = left.union(right)
  assert_true(combined.contains("left"))
  assert_true(combined.contains("right"))
  assert_true(left.is_subset_of(combined))
  let target = @src.CountingBloomFilter::with_size(4096, 4)
  target.insert("target")
  target.merge(combined)
  assert_true(target.contains("left"))
  assert_true(target.contains("target"))
}

///|
test "guide cuckoo filter insert contains remove" {
  let filter = @src.CuckooFilter::new(10_000)
  assert_true(filter.insert("session-1"))
  assert_true(filter.contains("session-1"))
  assert_true(filter.remove("session-1"))
  assert_false(filter.contains("session-1"))
}

///|
test "guide cuckoo filter union preserves both inputs" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  match left.union(right) {
    Some(combined) => assert_true(combined.contains_all(["left", "right"]))
    None => abort("combined filter is full")
  }
}

///|
test "guide cuckoo filter intersection keeps shared keys only" {
  let shared_left = @src.CuckooFilter::with_size(64, 4)
  let shared_right = @src.CuckooFilter::with_size(64, 4)
  assert_true(shared_left.insert_all(["keep", "left-only"]))
  assert_true(shared_right.insert_all(["keep", "right-only"]))
  let common = shared_left.intersection(shared_right)
  assert_true(common.contains("keep"))
  assert_false(common.contains("left-only"))
  assert_false(common.contains("right-only"))
}

///|
test "guide cuckoo filter subset comparison" {
  let left = @src.CuckooFilter::with_size(64, 4)
  let right = @src.CuckooFilter::with_size(64, 4)
  assert_true(left.insert("left"))
  assert_true(right.insert("right"))
  match left.union(right) {
    Some(combined) => {
      assert_true(left.is_subset_of(combined))
      assert_true(right.is_subset_of(combined))
    }
    None => abort("combined filter is full")
  }
}

///|
test "guide concurrent bloom filter basic flow" {
  let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
  filter.insert("shared")
  assert_true(filter.contains("shared"))
  let keys = ["a", "b", "c"]
  filter.insert_all(keys)
  assert_true(filter.contains_all(keys))
  assert_eq(filter.insert_all_if_absent(keys), 0)
}

///|
test "guide concurrent counting bloom filter removal" {
  let filter = @src.ConcurrentCountingBloomFilter::new(1000, 0.01)
  filter.insert("shared")
  assert_true(filter.remove("shared"))
  assert_false(filter.contains("shared"))
}

///|
test "guide concurrent cuckoo filter basic flow" {
  let filter = @src.ConcurrentCuckooFilter::new(1000)
  assert_true(filter.insert("session"))
  assert_true(filter.contains("session"))
  assert_true(filter.remove("session"))
}

///|
test "guide concurrent snapshot is isolated from later writes" {
  let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
  filter.insert("before")
  let snapshot = filter.snapshot()
  filter.insert("after")
  assert_eq(snapshot.count(), 1)
  assert_true(snapshot.contains("before"))
}

///|
test "guide occupancy and storage statistics" {
  let filter = @src.BloomFilter::new(1000, 0.01)
  filter.insert("value")
  let ratio = filter.fill_ratio()
  assert_true(ratio > 0.0 && ratio <= 1.0)
  assert_true(filter.set_bit_count() > 0)
  assert_true(filter.estimated_item_count() > 0.0)
  assert_true(filter.memory_bytes() > 0L)
  let counting = @src.CountingBloomFilter::new(1000, 0.01)
  counting.insert("value")
  assert_true(counting.occupied_slot_count() > 0)
  assert_true(counting.fill_ratio() > 0.0)
  let cuckoo = @src.CuckooFilter::new(1000)
  assert_true(cuckoo.insert("value"))
  assert_true(cuckoo.load_factor() > 0.0)
  assert_true(cuckoo.capacity() > 0)
}

///|
test "guide serialization round trips every filter type" {
  let bloom = @src.BloomFilter::new(1000, 0.01)
  bloom.insert("saved")
  let bloom_restored = @src.BloomFilter::from_bytes(bloom.to_bytes())
  assert_true(bloom_restored.contains("saved"))
  assert_eq(bloom_restored.count(), bloom.count())
  let counting = @src.CountingBloomFilter::new(1000, 0.01)
  counting.insert("saved")
  counting.insert("saved")
  let counting_restored = @src.CountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_true(counting_restored.contains("saved"))
  assert_eq(counting_restored.count_of("saved"), 2)
  let cuckoo = @src.CuckooFilter::new(1000)
  assert_true(cuckoo.insert("saved"))
  let cuckoo_restored = @src.CuckooFilter::from_bytes(cuckoo.to_bytes())
  assert_true(cuckoo_restored.contains("saved"))
  assert_eq(cuckoo_restored.count(), 1)
}

///|
test "guide concurrent wrappers serialize through the lock" {
  let bloom = @src.ConcurrentBloomFilter::new(1000, 0.01)
  bloom.insert("saved")
  let bloom_restored = @src.ConcurrentBloomFilter::from_bytes(bloom.to_bytes())
  assert_true(bloom_restored.contains("saved"))
  let counting = @src.ConcurrentCountingBloomFilter::new(1000, 0.01)
  counting.insert("saved")
  let counting_restored = @src.ConcurrentCountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_true(counting_restored.contains("saved"))
  let cuckoo = @src.ConcurrentCuckooFilter::new(1000)
  assert_true(cuckoo.insert("saved"))
  let cuckoo_restored = @src.ConcurrentCuckooFilter::from_bytes(
    cuckoo.to_bytes(),
  )
  assert_true(cuckoo_restored.contains("saved"))
}

///|
test "guide concurrent wrappers expose merge and copy helpers" {
  let left = @src.ConcurrentBloomFilter::with_size(4096, 4)
  let right = @src.BloomFilter::with_size(4096, 4)
  left.insert("left")
  right.insert("right")
  left.merge(right)
  assert_true(left.contains("right"))
  let common = left.intersection(right)
  assert_true(common.contains("right"))
  assert_true(common.is_subset_of(left.snapshot()))
  let counting = @src.ConcurrentCountingBloomFilter::with_size(4096, 4)
  let counting_right = @src.CountingBloomFilter::with_size(4096, 4)
  counting.insert("left")
  counting_right.insert("right")
  counting.merge(counting_right)
  assert_true(counting.contains("right"))
  let cuckoo = @src.ConcurrentCuckooFilter::with_size(64, 4)
  let cuckoo_right = @src.CuckooFilter::with_size(64, 4)
  assert_true(cuckoo.insert("left"))
  assert_true(cuckoo_right.insert("right"))
  assert_true(cuckoo.merge(cuckoo_right))
  assert_true(cuckoo.contains("right"))
  assert_true(cuckoo.intersection(cuckoo_right).contains("right"))
}
