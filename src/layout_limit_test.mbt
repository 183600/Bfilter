///|
test "panic bloom family with_size rejects sizes just past the limit" {
  @src.BloomFilter::with_size(2147483585, 1) |> ignore
}

///|
test "panic blocked bloom with_size rejects sizes just past the limit" {
  @src.BlockedBloomFilter::with_size(2147483137, 1) |> ignore
}

///|
test "panic counting family with_size rejects slots just past the limit" {
  @src.CountingBloomFilter::with_size(1073741809, 1) |> ignore
}

///|
test "panic compact counting with_size rejects slots just past the limit" {
  @src.CompactCountingBloomFilter::with_size(1073741809, 1) |> ignore
}

///|
test "panic cuckoo with_size rejects too many buckets" {
  @src.CuckooFilter::with_size(1073741825, 1) |> ignore
}

///|
test "panic cuckoo optimal size rejects one item past the limit" {
  @src.CuckooFilter::optimal_size(536870913) |> ignore
}
