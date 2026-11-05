///|
/// Simple test to verify BloomFilter functionality
///|
let filter = @src.BloomFilter::new(1000, 0.01)
assert_true(filter.is_empty())
assert_eq(filter.count(), 0)
filter.insert("alpha")
assert_true(filter.contains("alpha"))
assert_false(filter.contains("gamma"))
assert_eq(filter.count(), 1)
