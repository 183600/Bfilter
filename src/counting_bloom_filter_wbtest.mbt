///|
fn duplicate_position_key() -> (String, Int32) {
  for i = 0; i < 100000; i = i + 1 {
    let key = "dup-" + i.to_string()
    let (h1, h2) = key_hashes(key)
    let seen : Array[Int32] = []
    for j = 0; j < 20; j = j + 1 {
      let pos = bit_index(h1, h2, j, 48UL)
      if seen.contains(pos) {
        return (key, pos)
      }
      seen.push(pos)
    }
  }
  abort("no key with duplicate hash positions found")
}

///|
test "counting bloom filter removes duplicate hash positions" {
  let (key, _) = duplicate_position_key()
  let filter = CountingBloomFilter::with_size(48, 20)
  filter.insert(key)
  assert_true(filter.remove(key))
  assert_false(filter.contains(key))
  assert_eq(filter.count(), 0)
}

///|
test "counting bloom filter refuses to underflow duplicate hash positions" {
  let (key, duplicate) = duplicate_position_key()
  let filter = CountingBloomFilter::with_size(48, 20)
  filter.insert(key)
  filter.set_counter(duplicate, 1UL)
  assert_false(filter.remove(key))
  assert_eq(filter.counter_at(duplicate), 1UL)
  assert_eq(filter.count(), 1)
}
