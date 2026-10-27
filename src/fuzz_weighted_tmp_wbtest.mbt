///|
test "fuzz weighted counting removals drain selected lanes" {
  let layouts = [(16, 1), (16, 7), (16, 31), (16, 65), (48, 70), (512, 4), (512, 100), (4096, 13)]
  for layout in layouts {
    let (slots, hashes) = layout
    for n = 0; n <= 300; n = n + 1 {
      let filter = CountingBloomFilter::with_size(slots, hashes)
      for i = 0; i < n; i = i + 1 {
        filter.insert("key")
      }
      let mut removed = 0
      while filter.remove("key") {
        removed = removed + 1
        if removed > n {
          println("counting removed too many slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " n=" + n.to_string())
          panic()
        }
      }
      if filter.contains("key") {
        println("counting still contains slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " n=" + n.to_string() + " removed=" + removed.to_string())
        panic()
      }
      if filter.occupied_slot_count() != 0 {
        println("counting residue slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " n=" + n.to_string() + " removed=" + removed.to_string() + " occ=" + filter.occupied_slot_count().to_string())
        panic()
      }
      let compact = CompactCountingBloomFilter::with_size(slots, hashes)
      for i = 0; i < n; i = i + 1 {
        compact.insert("key")
      }
      let mut cremoved = 0
      while compact.remove("key") {
        cremoved = cremoved + 1
        if cremoved > n {
          println("compact removed too many slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " n=" + n.to_string())
          panic()
        }
      }
      if compact.contains("key") {
        println("compact still contains slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " n=" + n.to_string() + " removed=" + cremoved.to_string())
        panic()
      }
      if compact.occupied_slot_count() != 0 {
        println("compact residue slots=" + slots.to_string() + " hashes=" + hashes.to_string() + " n=" + n.to_string() + " removed=" + cremoved.to_string() + " occ=" + compact.occupied_slot_count().to_string())
        panic()
      }
    }
  }
}
