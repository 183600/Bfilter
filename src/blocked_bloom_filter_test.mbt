///|
test "blocked bloom filter inserts and queries keys" {
  let filter = @src.BlockedBloomFilter::new(1000, 0.01)
  let keys = ["alpha", "beta", "gamma", "delta"]
  filter.insert_all(keys)
  assert_eq(filter.count(), keys.length())
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains("alpha"))
  assert_false(filter.is_empty())
}

///|
test "blocked bloom filter rounds storage to whole blocks" {
  let single = @src.BlockedBloomFilter::with_size(1, 3)
  assert_eq(single.bit_count(), 512)
  assert_eq(single.block_count(), 1)
  assert_eq(single.memory_bytes(), 64L)
  let pair = @src.BlockedBloomFilter::with_size(513, 3)
  assert_eq(pair.bit_count(), 1024)
  assert_eq(pair.block_count(), 2)
  assert_eq(pair.memory_bytes(), 128L)
}

///|
test "blocked bloom filter conditional insertion skips duplicates" {
  let filter = @src.BlockedBloomFilter::with_size(4096, 4)
  assert_true(filter.insert_if_absent("once"))
  assert_false(filter.insert_if_absent("once"))
  assert_eq(filter.count(), 1)
  assert_eq(filter.insert_all_if_absent(["once", "twice", "twice"]), 1)
  assert_eq(filter.count(), 2)
  assert_true(filter.contains_all(["once", "twice"]))
}

///|
test "blocked bloom filter batch queries stop at definite misses" {
  let filter = @src.BlockedBloomFilter::new(1000, 0.01)
  let keys = ["red", "green", "blue"]
  filter.insert_all(keys)
  assert_true(filter.contains_all(keys))
  assert_true(filter.contains_any(["missing", "red"]))
  let empty : Array[String] = []
  assert_false(filter.contains_any(empty))
  assert_true(filter.contains_all(empty))
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_eq(filter.set_bit_count(), 0)
}

///|
test "blocked bloom filter statistics reflect insertions" {
  let filter = @src.BlockedBloomFilter::new(1000, 0.01)
  assert_eq(filter.false_positive_rate(), 0.0)
  assert_eq(filter.estimated_item_count(), 0.0)
  filter.insert_all(["one", "two", "three"])
  assert_true(filter.set_bit_count() > 0)
  assert_true(filter.fill_ratio() > 0.0 && filter.fill_ratio() <= 1.0)
  assert_true(filter.estimated_item_count() > 0.0)
  assert_true(filter.false_positive_rate() > 0.0)
  assert_true(filter.false_positive_rate() < 0.1)
}

///|
test "blocked bloom filter set operations combine matching layouts" {
  let left = @src.BlockedBloomFilter::with_size(4096, 4)
  let right = @src.BlockedBloomFilter::with_size(4096, 4)
  left.insert("left")
  right.insert("right")
  let combined = left.union(right)
  assert_true(combined.contains("left"))
  assert_true(combined.contains("right"))
  assert_true(left.is_subset_of(combined))
  assert_true(right.is_subset_of(combined))
  assert_eq(combined.count(), left.count() + right.count())
  let common = left.intersection(right)
  assert_true(common.is_subset_of(left))
  assert_true(common.is_subset_of(right))
  assert_eq(common.count(), left.count().min(right.count()))
  assert_true(
    left.is_disjoint_from(@src.BlockedBloomFilter::with_size(4096, 4)),
  )
  let target = @src.BlockedBloomFilter::with_size(4096, 4)
  target.insert("target")
  target.merge(combined)
  assert_true(target.contains("left"))
  assert_true(target.contains("target"))
}

///|
test "blocked bloom filter copies are independent" {
  let original = @src.BlockedBloomFilter::with_size(4096, 4)
  original.insert("before")
  let copy = original.copy()
  copy.insert("after")
  assert_true(copy.contains("after"))
  assert_eq(original.count(), 1)
  original.clear()
  assert_true(original.is_empty())
  assert_true(copy.contains("before"))
}

///|
test "panic blocked bloom filter rejects incompatible layouts" {
  let left = @src.BlockedBloomFilter::with_size(512, 3)
  let right = @src.BlockedBloomFilter::with_size(1024, 3)
  left.union(right) |> ignore
}

///|
test "panic blocked bloom filter rejects invalid configuration" {
  @src.BlockedBloomFilter::new(0, 0.01) |> ignore
}

///|
test "panic blocked bloom filter rejects invalid sizes" {
  @src.BlockedBloomFilter::with_size(0, 1) |> ignore
  @src.BlockedBloomFilter::with_size(512, 0) |> ignore
}

///|
test "guide blocked bloom example" {
  let filter = @src.BlockedBloomFilter::new(10_000, 0.001)
  filter.insert_all(["alpha", "beta"])
  assert_true(filter.contains("alpha"))
  assert_true(filter.contains_all(["alpha", "beta"]))
  assert_eq(filter.bit_count() % 512, 0)
  assert_eq(filter.block_count(), filter.bit_count() / 512)
}
