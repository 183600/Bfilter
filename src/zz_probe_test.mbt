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
  println("ka=" + ka.length().to_string() + " kb=" + kb.length().to_string())
  let f = @src.CuckooFilter::with_size(bc, bs)
  let mut ok = true
  for k in ka {
    if !f.insert(k) {
      ok = false
      println(
        "fresh ka fail key=" + k.to_string() + " count=" + f.count().to_string(),
      )
      break
    }
  }
  if ok {
    for k in kb {
      if !f.insert(k) {
        ok = false
        println(
          "fresh kb fail key=" +
          k.to_string() +
          " count=" +
          f.count().to_string(),
        )
        break
      }
    }
  }
  println("fresh total=" + f.count().to_string())
}
