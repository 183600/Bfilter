///|
test "fuzz optimal size matches constructors" {
  let rates = [0.5, 0.1, 0.05, 0.01, 0.001]
  for n = 1; n <= 2000; n = n + 7 {
    for rate in rates {
      let (bits, hashes) = BloomFilter::optimal_size(n, rate)
      let bloom = BloomFilter::new(n, rate)
      if bloom.bit_count() != bits || bloom.hash_count() != hashes {
        println("bloom mismatch n=" + n.to_string() + " rate=" + rate.to_string())
        panic()
      }
      let (slots, chashes) = CountingBloomFilter::optimal_size(n, rate)
      let counting = CountingBloomFilter::new(n, rate)
      if counting.slot_count() != slots || counting.hash_count() != chashes {
        println("counting mismatch n=" + n.to_string() + " rate=" + rate.to_string())
        panic()
      }
      let (cslots, cchashes) = CompactCountingBloomFilter::optimal_size(n, rate)
      let compact = CompactCountingBloomFilter::new(n, rate)
      if compact.slot_count() != cslots || compact.hash_count() != cchashes {
        println("compact mismatch n=" + n.to_string() + " rate=" + rate.to_string())
        panic()
      }
      let (bbits, bhashes) = BlockedBloomFilter::optimal_size(n, rate)
      let blocked = BlockedBloomFilter::new(n, rate)
      if blocked.bit_count() != bbits || blocked.hash_count() != bhashes {
        println("blocked mismatch n=" + n.to_string() + " rate=" + rate.to_string())
        panic()
      }
    }
  }
}
