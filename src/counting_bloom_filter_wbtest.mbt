///|
test "counting bloom filter removes duplicate hash positions" {
  let filter = CountingBloomFilter::with_size(48, 20)
  filter.insert("dup-4")
  assert_true(filter.remove("dup-4"))
  assert_false(filter.contains("dup-4"))
  assert_eq(filter.count(), 0)
}

///|
test "counting bloom filter refuses to underflow duplicate hash positions" {
  let filter = CountingBloomFilter::with_size(48, 20)
  filter.insert("dup-4")
  filter.set_counter(38, 1UL)
  assert_false(filter.remove("dup-4"))
  assert_eq(filter.counter_at(38), 1UL)
  assert_eq(filter.count(), 1)
}
