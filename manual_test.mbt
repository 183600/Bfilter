///|
/// Manual test to verify BloomFilter functionality
///|
let filter = @src.BloomFilter::new(1000, 0.01)
filter.insert("alpha")
filter.insert("beta")
assert_true(filter.contains("alpha"))
assert_true(filter.contains("beta"))
assert_false(filter.contains("gamma"))
assert_eq(filter.count(), 2)
assert_eq(filter.bit_count() % 64, 0)
assert_true(filter.hash_count() > 0)
