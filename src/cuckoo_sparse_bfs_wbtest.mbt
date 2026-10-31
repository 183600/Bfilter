///|
fn sparse_bfs_fingerprints(filter : CuckooFilter, wanted : Int32) -> Array[Byte] {
  let result : Array[Byte] = []
  let mut key = 0
  while result.length() < wanted && key < 100_000 {
    let (_, fingerprint) = filter.key_info(key)
    let mut duplicate = false
    for existing in result {
      if existing == fingerprint {
        duplicate = true
      }
    }
    if !duplicate {
      result.push(fingerprint)
    }
    key = key + 1
  }
  result
}

///|
test "sparse cuckoo bfs moves an augmenting path without losing fingerprints" {
  let filter = CuckooFilter::with_size(131_072, 2)
  assert_true(filter.bucket_count > CUCKOO_BFS_BUCKET_LIMIT)
  let fingerprints = sparse_bfs_fingerprints(filter, 8)
  assert_eq(fingerprints.length(), 8)
  let start = 0

  // Pick two distinct occupied candidate buckets for the new key. The new key
  // hashes deterministically, so fill both buckets to force the sparse search
  // past its direct insertion checks.
  let mut first_index = 0
  let mut first_alternate = 0
  let mut second_index = 1
  let mut second_alternate = 0
  let mut found = false
  while first_index < fingerprints.length() && !found {
    first_alternate = filter.alternate_index(start, fingerprints[first_index])
    if first_alternate != start {
      second_index = 0
      while second_index < fingerprints.length() {
        second_alternate = filter.alternate_index(
          start,
          fingerprints[second_index],
        )
        if second_alternate != start &&
          second_alternate != first_alternate {
          found = true
          break
        }
        second_index = second_index + 1
      }
    }
    if !found {
      first_index = first_index + 1
    }
  }
  assert_true(found)
  assert_true(first_index != second_index)

  // Put one occupant of the first alternate bucket in a third bucket, so the
  // path must move both fingerprints before the new key can enter `start`.
  let mut path_index = 0
  let mut path_alternate = 0
  let mut have_path = false
  for i = 0; i < fingerprints.length(); i = i + 1 {
    let alternate = filter.alternate_index(
      first_alternate,
      fingerprints[i],
    )
    if alternate != start &&
      alternate != first_alternate &&
      alternate != second_alternate {
      path_index = i
      path_alternate = alternate
      have_path = true
      break
    }
  }
  assert_true(have_path)

  filter.buckets[start * filter.bucket_size] = fingerprints[first_index]
  filter.buckets[start * filter.bucket_size + 1] = fingerprints[second_index]
  filter.buckets[first_alternate * filter.bucket_size] = fingerprints[path_index]
  filter.buckets[first_alternate * filter.bucket_size + 1] = fingerprints[6]
  filter.buckets[second_alternate * filter.bucket_size] = fingerprints[7]
  filter.buckets[second_alternate * filter.bucket_size + 1] = fingerprints[5]
  filter.inserted = 6

  let placed : Array[(Int32, Byte)] = [
    (start, fingerprints[first_index]),
    (start, fingerprints[second_index]),
    (first_alternate, fingerprints[path_index]),
    (first_alternate, fingerprints[6]),
    (second_alternate, fingerprints[7]),
    (second_alternate, fingerprints[5]),
  ]
  let before = filter.to_bytes()
  let fresh = fingerprints[4]
  assert_true(filter.insert_fingerprint_bfs(start, fresh))
  assert_eq(filter.count(), 7)
  for entry in placed {
    let (bucket, fingerprint) = entry
    let alternate = filter.alternate_index(bucket, fingerprint)
    assert_true(
      filter.bucket_contains(bucket, fingerprint) ||
      filter.bucket_contains(alternate, fingerprint),
    )
  }
  let fresh_alternate = filter.alternate_index(start, fresh)
  assert_true(
    filter.bucket_contains(start, fresh) ||
    filter.bucket_contains(fresh_alternate, fresh),
  )
  assert_true(
    filter.bucket_contains(path_alternate, fingerprints[path_index]),
  )
  let restored = CuckooFilter::from_bytes(filter.to_bytes())
  assert_eq(restored.count(), filter.count())
  assert_true(restored.bucket_contains(start, fresh) ||
    restored.bucket_contains(fresh_alternate, fresh))
  assert_true(before != filter.to_bytes())
}

///|
test "sparse cuckoo bfs skips a repeated alternate bucket" {
  let filter = CuckooFilter::with_size(131_072, 2)
  let fingerprints = sparse_bfs_fingerprints(filter, 4)
  let start = 0
  let moved = fingerprints[0]
  let alternate = filter.alternate_index(start, moved)
  assert_true(alternate != start)
  let occupant = fingerprints[1]
  let fresh = fingerprints[2]
  filter.buckets[start * filter.bucket_size] = moved
  filter.buckets[start * filter.bucket_size + 1] = moved
  filter.buckets[alternate * filter.bucket_size] = occupant
  filter.buckets[alternate * filter.bucket_size + 1] = occupant
  filter.inserted = 4
  let before = filter.to_bytes()
  let added = filter.insert_fingerprint_bfs(start, fresh)
  if added {
    assert_eq(filter.count(), 5)
    let fresh_alternate = filter.alternate_index(start, fresh)
    assert_true(
      filter.bucket_contains(start, fresh) ||
      filter.bucket_contains(fresh_alternate, fresh),
    )
  } else {
    assert_eq(filter.to_bytes(), before)
  }
}
