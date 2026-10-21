///|
test "blocked bloom filter reports definite batch and set-operation misses" {
  let empty = @src.BlockedBloomFilter::with_size(1024, 4)
  let filled = @src.BlockedBloomFilter::with_size(1024, 4)
  filled.insert("shared")
  assert_false(filled.contains_all(["shared", "absent"]))
  assert_false(filled.is_subset_of(empty))
  assert_true(empty.is_subset_of(filled))
  assert_true(empty.is_disjoint_from(filled))
  let same = @src.BlockedBloomFilter::with_size(1024, 4)
  same.insert("shared")
  assert_false(filled.is_disjoint_from(same))
}

///|
test "batch membership stops at the first definite miss" {
  let bloom = @src.BloomFilter::with_size(1 << 20, 2)
  bloom.insert("present")
  assert_false(bloom.contains_all(["present", "absent-a"]))
  let counting = @src.CountingBloomFilter::with_size(1 << 20, 2)
  counting.insert("present")
  assert_false(counting.contains_all(["present", "absent-b"]))
  let compact = @src.CompactCountingBloomFilter::with_size(1 << 20, 2)
  compact.insert("present")
  assert_false(compact.contains_all(["present", "absent-c"]))
  let scalable = @src.ScalableBloomFilter::new(1 << 20, 0.001)
  scalable.insert("present")
  assert_false(scalable.contains_all(["present", "absent-d"]))
  let cuckoo = @src.CuckooFilter::with_size(1024, 4)
  assert_true(cuckoo.insert("present"))
  assert_false(cuckoo.contains_all(["present", "absent-e"]))
  let blocked = @src.BlockedBloomFilter::with_size(1 << 20, 2)
  blocked.insert("present")
  assert_false(blocked.contains_all(["present", "absent-f"]))
}

///|
test "compact counting filter remove_all reports partial failures" {
  let filter = @src.CompactCountingBloomFilter::with_size(1024, 4)
  filter.insert_all(["a", "b"])
  assert_false(filter.remove_all(["a", "missing"]))
  assert_false(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_eq(filter.count(), 1)
}

///|
test "full filters report infinite estimated item counts" {
  let counting = @src.CountingBloomFilter::with_size(16, 1)
  for i = 0; i < 4096; i = i + 1 {
    counting.insert(i)
  }
  assert_eq(counting.occupied_slot_count(), 16)
  assert_true(counting.estimated_item_count() > 1.0e300)

  let compact = @src.CompactCountingBloomFilter::with_size(16, 1)
  for i = 0; i < 4096; i = i + 1 {
    compact.insert(i)
  }
  assert_eq(compact.occupied_slot_count(), 16)
  assert_true(compact.estimated_item_count() > 1.0e300)

  let blocked = @src.BlockedBloomFilter::with_size(512, 1)
  for i = 0; i < 20000; i = i + 1 {
    blocked.insert(i)
  }
  assert_eq(blocked.set_bit_count(), blocked.bit_count())
  assert_eq(blocked.fill_ratio(), 1.0)
  assert_true(blocked.estimated_item_count() > 1.0e300)
}

///|
test "panic bloom filter new rejects layouts beyond the supported size" {
  @src.BloomFilter::new(2147483647, 0.000000001) |> ignore
}

///|
test "panic counting bloom filter new rejects layouts beyond the supported size" {
  @src.CountingBloomFilter::new(2147483647, 0.000000001) |> ignore
}

///|
test "panic counting bloom filter new rejects slots beyond the supported size" {
  @src.CountingBloomFilter::new(50000000, 0.00001) |> ignore
}

///|
test "panic compact counting filter new rejects layouts beyond the supported size" {
  @src.CompactCountingBloomFilter::new(2147483647, 0.000000001) |> ignore
}

///|
test "panic compact counting filter new rejects slots beyond the supported size" {
  @src.CompactCountingBloomFilter::new(50000000, 0.00001) |> ignore
}

///|
test "panic blocked bloom filter new rejects layouts beyond the supported size" {
  @src.BlockedBloomFilter::new(2147483647, 0.000000001) |> ignore
}

///|
test "panic blocked bloom filter new rejects a zero false positive rate" {
  @src.BlockedBloomFilter::new(10, 0.0) |> ignore
}

///|
test "concurrent blocked filter supports conditional insertion and fill ratio" {
  let filter = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("a"))
  assert_false(filter.insert_if_absent("a"))
  assert_eq(filter.insert_all_if_absent(["a", "b", "b"]), 1)
  assert_true(filter.fill_ratio() > 0.0)
  assert_true(filter.fill_ratio() <= 1.0)
}

///|
test "concurrent compact counting filter supports conditionals and bulk removal" {
  let filter = @src.ConcurrentCompactCountingBloomFilter::with_size(1024, 4)
  assert_true(filter.insert_if_absent("a"))
  assert_false(filter.insert_if_absent("a"))
  filter.insert("b")
  assert_true(filter.remove_all(["a"]))
  assert_false(filter.contains("a"))
  assert_true(filter.contains("b"))
  assert_true(filter.occupied_slot_count() > 0)
}

///|
test "full bloom filters report infinite estimated item counts" {
  let filter = @src.BloomFilter::with_size(64, 1)
  for i = 0; i < 1024; i = i + 1 {
    filter.insert(i)
  }
  assert_eq(filter.set_bit_count(), filter.bit_count())
  assert_true(filter.estimated_item_count() > 1.0e300)
}

///|
test "counting filters handle hash counts wider than their counters" {
  let filter = @src.CountingBloomFilter::with_size(16, 1048576)
  filter.insert("wide")
  assert_eq(filter.count_of("wide"), 65535)
  assert_eq(filter.count(), 1)
  let restored = @src.CountingBloomFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count_of("wide"), 65535)
  assert_true(restored.remove("wide"))
  assert_eq(restored.count(), 0)
  assert_false(restored.contains("wide"))
}
