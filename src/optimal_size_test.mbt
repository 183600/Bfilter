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

///|
test "scalable optimal size matches the first constructed slice" {
  for expected in [1, 4, 1000, 100_000] {
    for rate in [0.5, 0.01, 0.001] {
      let (bloom_bits, bloom_hashes) = @src.ScalableBloomFilter::optimal_size(
        expected, rate,
      )
      let bloom = @src.ScalableBloomFilter::new(expected, rate)
      assert_eq(bloom.slice_count(), 1)
      assert_eq(bloom_bits, bloom.bit_count())
      assert_eq(
        (bloom_bits, bloom_hashes),
        @src.BloomFilter::optimal_size(expected, rate * 0.5),
      )
      assert_eq(bloom_bits % 64, 0)

      let (counting_slots, counting_hashes) = @src.ScalableCountingBloomFilter::optimal_size(
        expected, rate,
      )
      let counting = @src.ScalableCountingBloomFilter::new(expected, rate)
      assert_eq(counting.slice_count(), 1)
      assert_eq(counting_slots.to_int64(), counting.slot_count())
      assert_eq(
        (counting_slots, counting_hashes),
        @src.CountingBloomFilter::optimal_size(expected, rate * 0.5),
      )
      assert_eq(counting_slots % 16, 0)
    }
  }
}

///|
test "concurrent scalable optimal size matches the constructed first slice" {
  for expected in [1, 1000] {
    for rate in [0.5, 0.01] {
      let bloom_layout = @src.ConcurrentScalableBloomFilter::optimal_size(
        expected, rate,
      )
      assert_eq(
        bloom_layout,
        @src.ScalableBloomFilter::optimal_size(expected, rate),
      )
      let bloom = @src.ConcurrentScalableBloomFilter::new(expected, rate)
      assert_eq(bloom_layout.0, bloom.bit_count())
      assert_eq(
        bloom_layout,
        @src.BloomFilter::optimal_size(expected, rate * 0.5),
      )

      let counting_layout = @src.ConcurrentScalableCountingBloomFilter::optimal_size(
        expected, rate,
      )
      assert_eq(
        counting_layout,
        @src.ScalableCountingBloomFilter::optimal_size(expected, rate),
      )
      let counting = @src.ConcurrentScalableCountingBloomFilter::new(
        expected, rate,
      )
      assert_eq(counting_layout.0.to_int64(), counting.slot_count())
    }
  }
}

///|
test "panic scalable optimal size rejects invalid arguments" {
  @src.ScalableBloomFilter::optimal_size(0, 0.01) |> ignore
}

///|
test "panic scalable optimal size rejects an invalid rate" {
  @src.ScalableBloomFilter::optimal_size(10, 1.0) |> ignore
}

///|
test "panic scalable counting optimal size rejects invalid arguments" {
  @src.ScalableCountingBloomFilter::optimal_size(10, 0.0) |> ignore
}

///|
test "panic scalable counting optimal size rejects an aggregate-oversized first slice" {
  // The per-slice layout fits, but this first slice alone exceeds the aggregate
  // slot budget that `ScalableCountingBloomFilter::new` enforces before it
  // allocates the slice. The planner must reject the same arguments.
  @src.ScalableCountingBloomFilter::optimal_size(112_022_450, 0.02) |> ignore
}

///|
test "panic scalable counting constructor rejects an aggregate-oversized first slice" {
  @src.ScalableCountingBloomFilter::new(112_022_450, 0.02) |> ignore
}

///|
test "panic concurrent scalable optimal size rejects invalid arguments" {
  @src.ConcurrentScalableBloomFilter::optimal_size(0, 0.01) |> ignore
}

