///|
test "bloom filters detect definite disjointness" {
  let left = @src.BloomFilter::with_size(1 << 20, 2)
  let right = @src.BloomFilter::with_size(1 << 20, 2)
  assert_true(left.is_disjoint_from(right))
  left.insert_all(["left-a", "left-b"])
  right.insert_all(["right-a", "right-b"])
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
  right.insert("left-a")
  assert_false(left.is_disjoint_from(right))
}

///|
test "counting filters detect definite disjointness" {
  let left = @src.CountingBloomFilter::with_size(1 << 20, 2)
  let right = @src.CountingBloomFilter::with_size(1 << 20, 2)
  assert_true(left.is_disjoint_from(right))
  left.insert_all(["left-a", "left-b"])
  right.insert_all(["right-a", "right-b"])
  assert_true(left.is_disjoint_from(right))
  right.insert("left-a")
  assert_false(left.is_disjoint_from(right))
  assert_true(right.remove("left-a"))
  assert_true(left.is_disjoint_from(right))
}

///|
test "compact counting filters detect definite disjointness" {
  let left = @src.CompactCountingBloomFilter::with_size(1 << 20, 2)
  let right = @src.CompactCountingBloomFilter::with_size(1 << 20, 2)
  assert_true(left.is_disjoint_from(right))
  left.insert_all(["left-a", "left-b"])
  right.insert_all(["right-a", "right-b"])
  assert_true(left.is_disjoint_from(right))
  right.insert("left-a")
  assert_false(left.is_disjoint_from(right))
  assert_true(right.remove("left-a"))
  assert_true(left.is_disjoint_from(right))
}

///|
test "cuckoo filters detect definite disjointness" {
  let left = @src.CuckooFilter::with_size(1024, 4)
  let right = @src.CuckooFilter::with_size(1024, 4)
  assert_true(left.is_disjoint_from(right))
  ignore(left.insert_all(["left-a", "left-b"]))
  ignore(right.insert_all(["right-a", "right-b"]))
  assert_true(left.is_disjoint_from(right))
  ignore(right.insert("left-a"))
  assert_false(left.is_disjoint_from(right))
  assert_true(right.remove("left-a"))
  assert_true(left.is_disjoint_from(right))
}

///|
test "scalable bloom filters detect definite disjointness" {
  let left = @src.ScalableBloomFilter::new(1 << 20, 0.001)
  let right = @src.ScalableBloomFilter::new(1 << 20, 0.001)
  assert_true(left.is_disjoint_from(right))
  for i = 0; i < 5; i = i + 1 {
    left.insert("left-" + i.to_string())
  }
  for i = 0; i < 5; i = i + 1 {
    right.insert("right-" + i.to_string())
  }
  assert_true(left.is_disjoint_from(right))
  right.insert("left-3")
  assert_false(left.is_disjoint_from(right))
}

///|
test "scalable bloom disjointness accepts an empty operand" {
  let left = @src.ScalableBloomFilter::new(1 << 16, 0.001)
  let right = @src.ScalableBloomFilter::new(1 << 16, 0.001)
  left.insert_all(["a", "b", "c"])
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
  right.insert_all(["d"])
  assert_true(left.is_disjoint_from(right))
}

///|
test "scalable counting disjointness accepts an empty operand" {
  let left = @src.ScalableCountingBloomFilter::new(1 << 16, 0.001)
  let right = @src.ScalableCountingBloomFilter::new(1 << 16, 0.001)
  left.insert_all(["a", "b", "c"])
  assert_true(left.is_disjoint_from(right))
  assert_true(right.is_disjoint_from(left))
  right.insert("d")
  assert_true(left.is_disjoint_from(right))
}

///|
test "scalable bloom disjointness rejects non-empty extra slices" {
  let short = @src.ScalableBloomFilter::new(2, 0.01)
  let long = @src.ScalableBloomFilter::new(2, 0.01)
  short.insert("early")
  for i = 0; i < 20; i = i + 1 {
    long.insert(i)
  }
  assert_true(long.slice_count() > short.slice_count())
  assert_false(long.is_disjoint_from(short))
  long.clear()
  assert_true(long.is_disjoint_from(short))
}

///|
test "panic disjointness rejects mismatched bloom layouts" {
  let bloom = @src.BloomFilter::with_size(1024, 3)
  let other = @src.BloomFilter::with_size(1024, 4)
  bloom.is_disjoint_from(other) |> ignore
}

///|
test "panic disjointness rejects mismatched counting layouts" {
  let counting = @src.CountingBloomFilter::with_size(1024, 3)
  let other = @src.CountingBloomFilter::with_size(1024, 4)
  counting.is_disjoint_from(other) |> ignore
}

///|
test "panic disjointness rejects mismatched compact layouts" {
  let compact = @src.CompactCountingBloomFilter::with_size(1024, 3)
  let other = @src.CompactCountingBloomFilter::with_size(1024, 4)
  compact.is_disjoint_from(other) |> ignore
}

///|
test "panic disjointness rejects mismatched cuckoo layouts" {
  let cuckoo = @src.CuckooFilter::with_size(1024, 4)
  let other = @src.CuckooFilter::with_size(512, 4)
  cuckoo.is_disjoint_from(other) |> ignore
}

///|
test "panic disjointness rejects mismatched scalable policies" {
  let scalable = @src.ScalableBloomFilter::new(4, 0.01)
  let other = @src.ScalableBloomFilter::new(8, 0.01)
  scalable.is_disjoint_from(other) |> ignore
}

///|
test "concurrent filters expose disjointness checks" {
  let bloom = @src.ConcurrentBloomFilter::with_size(1 << 20, 2)
  let bloom_other = @src.BloomFilter::with_size(1 << 20, 2)
  assert_true(bloom.is_disjoint_from(bloom_other))
  bloom.insert("shared")
  bloom_other.insert("shared")
  assert_false(bloom.is_disjoint_from(bloom_other))

  let counting = @src.ConcurrentCountingBloomFilter::with_size(1 << 20, 2)
  let counting_other = @src.CountingBloomFilter::with_size(1 << 20, 2)
  assert_true(counting.is_disjoint_from(counting_other))
  counting.insert("shared")
  counting_other.insert("shared")
  assert_false(counting.is_disjoint_from(counting_other))

  let compact = @src.ConcurrentCompactCountingBloomFilter::with_size(1 << 20, 2)
  let compact_other = @src.CompactCountingBloomFilter::with_size(1 << 20, 2)
  assert_true(compact.is_disjoint_from(compact_other))
  compact.insert("shared")
  compact_other.insert("shared")
  assert_false(compact.is_disjoint_from(compact_other))

  let cuckoo = @src.ConcurrentCuckooFilter::with_size(1024, 4)
  let cuckoo_other = @src.CuckooFilter::with_size(1024, 4)
  assert_true(cuckoo.is_disjoint_from(cuckoo_other))
  ignore(cuckoo.insert("shared"))
  ignore(cuckoo_other.insert("shared"))
  assert_false(cuckoo.is_disjoint_from(cuckoo_other))

  let scalable = @src.ConcurrentScalableBloomFilter::new(4, 0.01)
  let scalable_other = @src.ScalableBloomFilter::new(4, 0.01)
  assert_true(scalable.is_disjoint_from(scalable_other))
  scalable.insert("shared")
  scalable_other.insert("shared")
  assert_false(scalable.is_disjoint_from(scalable_other))
}

///|
test "scalable bloom disjointness handles slices with different layouts" {
  let grown = @src.ScalableBloomFilter::new(1, 0.001)
  let empty = @src.ScalableBloomFilter::new(1, 0.001)
  for i = 0; i < 20; i = i + 1 {
    grown.insert("grown-" + i.to_string())
  }
  assert_true(grown.slice_count() > 1)
  assert_true(grown.is_disjoint_from(empty))
  assert_true(empty.is_disjoint_from(grown))
  let other = @src.ScalableBloomFilter::new(1, 0.001)
  for i = 0; i < 20; i = i + 1 {
    other.insert("other-" + i.to_string())
  }
  assert_true(other.slice_count() > 1)
  assert_false(grown.is_disjoint_from(other))
  other.clear()
  assert_true(grown.is_disjoint_from(other))
}

///|
test "scalable bloom disjointness treats mismatched slice layouts as inconclusive" {
  let base = @src.BloomFilter::with_size(64, 10)
  base.insert("layout-base")
  let mut disjoint_key = -1
  for candidate = 0; candidate < 10_000; candidate = candidate + 1 {
    let probe = @src.BloomFilter::with_size(64, 10)
    probe.insert(candidate)
    if base.is_disjoint_from(probe) {
      disjoint_key = candidate
      break
    }
  }
  assert_true(disjoint_key >= 0)
  let left = @src.ScalableBloomFilter::new(1, 0.001)
  left.insert("layout-base")
  let right = @src.ScalableBloomFilter::new(1, 0.001)
  right.insert(disjoint_key)
  right.insert("layout-second")
  right.insert("layout-third")
  assert_eq(right.slice_count(), 2)
  assert_false(left.is_disjoint_from(right))
}

///|
test "scalable counting disjointness treats mismatched slice layouts as inconclusive" {
  let left = @src.ScalableCountingBloomFilter::new(1, 0.001)
  left.insert("first")
  left.insert("second")
  assert_eq(left.slice_count(), 2)
  assert_true(left.remove("first"))
  assert_false(left.contains("first"))
  let right = @src.ScalableCountingBloomFilter::new(1, 0.001)
  right.insert("other")
  assert_false(left.is_disjoint_from(right))
  assert_false(right.is_disjoint_from(left))
}
