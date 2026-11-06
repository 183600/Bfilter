///|
/// Test that concurrent wrappers panic on set operations with mismatched layouts.
/// This mirrors the behavior of non-concurrent filters which abort on layout mismatch.

///|
test "panic concurrent bloom filter merge rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent bloom filter merge rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent bloom filter union rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent bloom filter union rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent bloom filter intersection rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent bloom filter intersection rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent bloom filter is_subset_of rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent bloom filter is_subset_of rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent bloom filter is_disjoint_from rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent bloom filter is_disjoint_from rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter merge rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter merge rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter union rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter union rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter intersection rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter intersection rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter is_subset_of rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter is_subset_of rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter is_disjoint_from rejects mismatched bit count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(512, 4)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent blocked bloom filter is_disjoint_from rejects mismatched hash count" {
  let concurrent = @src.ConcurrentBlockedBloomFilter::with_size(1024, 4)
  concurrent.insert("key")
  let other = @src.BlockedBloomFilter::with_size(1024, 8)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent counting bloom filter merge rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent counting bloom filter merge rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent counting bloom filter union rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent counting bloom filter union rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent counting bloom filter intersection rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent counting bloom filter intersection rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent counting bloom filter is_subset_of rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent counting bloom filter is_subset_of rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent counting bloom filter is_disjoint_from rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent counting bloom filter is_disjoint_from rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter merge rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter merge rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter union rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter union rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter intersection rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter intersection rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter is_subset_of rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter is_subset_of rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter is_disjoint_from rejects mismatched slot count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(128, 4)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent compact counting bloom filter is_disjoint_from rejects mismatched hash count" {
  let concurrent = @src.ConcurrentCompactCountingBloomFilter::with_size(256, 4)
  concurrent.insert("key")
  let other = @src.CompactCountingBloomFilter::with_size(256, 8)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter merge rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter merge rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter union rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter union rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter intersection rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter intersection rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter is_subset_of rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter is_subset_of rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter is_disjoint_from rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent scalable bloom filter is_disjoint_from rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter merge rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter merge rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter union rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter union rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter intersection rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter intersection rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter is_subset_of rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter is_subset_of rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter is_disjoint_from rejects mismatched initial capacity" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(50, 0.01)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent scalable counting bloom filter is_disjoint_from rejects mismatched target rate" {
  let concurrent = @src.ConcurrentScalableCountingBloomFilter::new(100, 0.01)
  concurrent.insert("key")
  let other = @src.ScalableCountingBloomFilter::new(100, 0.05)
  other.insert("other")
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent cuckoo filter merge rejects mismatched bucket count" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(32, 4)
  ignore(other.insert("other"))
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent cuckoo filter merge rejects mismatched bucket size" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(64, 8)
  ignore(other.insert("other"))
  concurrent.merge(other) |> ignore
}

///|
test "panic concurrent cuckoo filter union rejects mismatched bucket count" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(32, 4)
  ignore(other.insert("other"))
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent cuckoo filter union rejects mismatched bucket size" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(64, 8)
  ignore(other.insert("other"))
  concurrent.union(other) |> ignore
}

///|
test "panic concurrent cuckoo filter intersection rejects mismatched bucket count" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(32, 4)
  ignore(other.insert("other"))
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent cuckoo filter intersection rejects mismatched bucket size" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(64, 8)
  ignore(other.insert("other"))
  concurrent.intersection(other) |> ignore
}

///|
test "panic concurrent cuckoo filter is_subset_of rejects mismatched bucket count" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(32, 4)
  ignore(other.insert("other"))
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent cuckoo filter is_subset_of rejects mismatched bucket size" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(64, 8)
  ignore(other.insert("other"))
  concurrent.is_subset_of(other) |> ignore
}

///|
test "panic concurrent cuckoo filter is_disjoint_from rejects mismatched bucket count" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(32, 4)
  ignore(other.insert("other"))
  concurrent.is_disjoint_from(other) |> ignore
}

///|
test "panic concurrent cuckoo filter is_disjoint_from rejects mismatched bucket size" {
  let concurrent = @src.ConcurrentCuckooFilter::with_size(64, 4)
  ignore(concurrent.insert("key"))
  let other = @src.CuckooFilter::with_size(64, 8)
  ignore(other.insert("other"))
  concurrent.is_disjoint_from(other) |> ignore
}