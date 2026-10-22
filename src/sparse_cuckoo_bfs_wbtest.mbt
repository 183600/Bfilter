///|
fn sparse_chain_fingerprints() -> (Byte, Byte, Int32, Int32) {
  let mask = 131071UL
  for first = 1; first < 256; first = first + 1 {
    let first_fingerprint = first.to_byte()
    let first_alternate = (fingerprint_hash(first_fingerprint) & mask).to_int()
    if first_alternate != 0 && first_alternate < 131072 {
      for second = 1; second < 256; second = second + 1 {
        let second_fingerprint = second.to_byte()
        if second_fingerprint != first_fingerprint {
          let second_alternate = (first_alternate.to_uint64() ^
            (fingerprint_hash(second_fingerprint) & mask)).to_int()
          if second_alternate != 0 && second_alternate != first_alternate {
            return (
              first_fingerprint,
              second_fingerprint,
              first_alternate,
              second_alternate,
            )
          }
        }
      }
    }
  }
  abort("no sparse cuckoo chain")
}

///|
test "sparse cuckoo augmenting path moves fingerprints through a full chain" {
  // Bucket counts above the dense-search limit use the map-backed BFS.
  let filter = CuckooFilter::with_size(65537, 1)
  assert_true(filter.bucket_count > CUCKOO_BFS_BUCKET_LIMIT)
  let (first, second, first_alternate, second_alternate) =
    sparse_chain_fingerprints()
  filter.buckets[0] = first
  filter.buckets[first_alternate] = second
  filter.inserted = 2
  assert_true(filter.insert_fingerprint_bfs_sparse(0, first))
  assert_eq(filter.inserted, 3)
  assert_eq(filter.buckets[0], first)
  assert_eq(filter.buckets[first_alternate], first)
  assert_eq(filter.buckets[second_alternate], second)
}
