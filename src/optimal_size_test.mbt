///|
test "bloom filter optimal size matches the constructed layout" {
  for expected in [1, 1000, 100_000] {
    for rate in [0.5, 0.01, 0.001] {
      let (bits, hashes) = @src.BloomFilter::optimal_size(expected, rate)
      let filter = @src.BloomFilter::new(expected, rate)
      assert_eq(bits, filter.bit_count())
      assert_eq(hashes, filter.hash_count())
      assert_eq(bits % 64, 0)
    }
  }
}

///|
test "counting filter optimal size matches the constructed layout" {
  for expected in [1, 1000, 100_000] {
    for rate in [0.5, 0.01, 0.001] {
      let (slots, hashes) = @src.CountingBloomFilter::optimal_size(
        expected, rate,
      )
      let filter = @src.CountingBloomFilter::new(expected, rate)
      assert_eq(slots, filter.slot_count())
      assert_eq(hashes, filter.hash_count())
      assert_eq(slots % 16, 0)
    }
  }
}

///|
test "compact counting optimally sizes exactly like the regular variant" {
  for expected in [1, 1000, 100_000] {
    for rate in [0.5, 0.01, 0.001] {
      let compact = @src.CompactCountingBloomFilter::optimal_size(
        expected, rate,
      )
      let regular = @src.CountingBloomFilter::optimal_size(expected, rate)
      assert_eq(compact, regular)
      let filter = @src.CompactCountingBloomFilter::new(expected, rate)
      assert_eq(compact.0, filter.slot_count())
      assert_eq(compact.1, filter.hash_count())
    }
  }
}

///|
test "blocked filter optimal size matches the constructed layout" {
  for expected in [1, 1000, 100_000] {
    for rate in [0.5, 0.01, 0.001] {
      let (bits, hashes) = @src.BlockedBloomFilter::optimal_size(expected, rate)
      let filter = @src.BlockedBloomFilter::new(expected, rate)
      assert_eq(bits, filter.bit_count())
      assert_eq(hashes, filter.hash_count())
      assert_eq(bits % 512, 0)
      assert_eq(bits / 512, filter.block_count())
    }
  }
}

///|
test "cuckoo filter optimal size matches the constructed layout" {
  for expected in [1, 10, 1000, 100_000] {
    let (buckets, size) = @src.CuckooFilter::optimal_size(expected)
    let filter = @src.CuckooFilter::new(expected)
    assert_eq(buckets, filter.bucket_count())
    assert_eq(size, filter.bucket_size())
    assert_eq(buckets & (buckets - 1), 0)
    assert_true(filter.capacity() >= expected)
  }
}

///|
test "panic bloom filter optimal size rejects invalid arguments" {
  @src.BloomFilter::optimal_size(0, 0.01) |> ignore
}

///|
test "panic bloom filter optimal size rejects an invalid rate" {
  @src.BloomFilter::optimal_size(10, 1.0) |> ignore
}

///|
test "panic counting filter optimal size rejects invalid arguments" {
  @src.CountingBloomFilter::optimal_size(0, 0.01) |> ignore
}

///|
test "panic compact counting filter optimal size rejects invalid arguments" {
  @src.CompactCountingBloomFilter::optimal_size(10, 0.0) |> ignore
}

///|
test "panic blocked filter optimal size rejects invalid arguments" {
  @src.BlockedBloomFilter::optimal_size(10, 0.0) |> ignore
}

///|
test "panic cuckoo filter optimal size rejects invalid arguments" {
  @src.CuckooFilter::optimal_size(0) |> ignore
}

///|
test "panic bloom filter optimal size rejects oversized layouts" {
  @src.BloomFilter::optimal_size(2147483647, 0.000000001) |> ignore
}

///|
test "panic counting filter optimal size rejects oversized layouts" {
  @src.CountingBloomFilter::optimal_size(2147483647, 0.000000001) |> ignore
}

///|
test "panic compact counting optimal size rejects oversized layouts" {
  @src.CompactCountingBloomFilter::optimal_size(50000000, 0.00001) |> ignore
}

///|
test "panic blocked filter optimal size rejects oversized layouts" {
  @src.BlockedBloomFilter::optimal_size(2147483647, 0.000000001) |> ignore
}

///|
test "panic cuckoo filter optimal size rejects oversized capacities" {
  @src.CuckooFilter::optimal_size(536870913) |> ignore
}
