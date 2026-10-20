///|
test "cuckoo union preserves colliding fingerprints" {
  let groups : Array[Array[String]] = Array::make(256, [])
  for i = 0; i < 20000; i = i + 1 {
    let key = "collision-" + i.to_string()
    let (hash, _) = key_hashes(key)
    let fp = ((hash >> 32) % 255UL + 1UL).to_int()
    let group = groups[fp]
    if group.length() < 8 {
      group.push(key)
    }
  }
  for fp = 1; fp < 256; fp = fp + 1 {
    let group = groups[fp]
    if group.length() >= 4 {
      let a = group[0]
      let b = group[1]
      let c = group[2]
      let left = CuckooFilter::with_size(64, 4)
      let right = CuckooFilter::with_size(64, 4)
      assert_true(left.insert(a))
      assert_true(left.insert(a))
      assert_true(right.insert(b))
      assert_true(right.insert(c))
      match left.union(right) {
        Some(combined) => {
          assert_true(combined.contains(a))
          assert_true(combined.contains(b))
          assert_true(combined.contains(c))
          assert_eq(combined.count(), 4)
          assert_true(left.is_subset_of(combined))
          assert_true(right.is_subset_of(combined))
          assert_true(combined.remove(a))
          assert_true(combined.remove(a))
          assert_true(combined.remove(b))
          assert_true(combined.remove(c))
          assert_true(combined.is_empty())
        }
        None => abort("unexpected union failure")
      }
    }
  }
}
