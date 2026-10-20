///|
test "probe cuckoo key multiset rebuild" {
  let bc = 8
  let bs = 4
  let seed0 = 53
  let a = @src.CuckooFilter::with_size(bc, bs)
  let b = @src.CuckooFilter::with_size(bc, bs)
  let mut seed = seed0
  let per_side = bc * bs / 4
  let ka : Array[Int32] = []
  let kb : Array[Int32] = []
  for step = 0; step < 20; step = step + 1 {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    let key = seed % 30
    let which = seed / 31 % 2
    if which == 0 {
      if a.count() < per_side && a.insert(key) {
        ka.push(key)
      }
    } else if b.count() < per_side && b.insert(key) {
      kb.push(key)
    }
  }
  assert_true(a.contains_all(ka))
  assert_true(b.contains_all(kb))
  let f = @src.CuckooFilter::with_size(bc, bs)
  for k in ka {
    assert_true(f.insert(k))
  }
  for k in kb {
    assert_true(f.insert(k))
  }
  assert_eq(f.count(), ka.length() + kb.length())
  assert_true(f.contains_all(ka))
  assert_true(f.contains_all(kb))
}
