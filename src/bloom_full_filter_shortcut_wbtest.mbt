///|
test "bloom full-filter shortcut follows the effective probe width" {
  let small = BloomFilter::with_size(64, 1)
  assert_false(small.should_check_full(2))
  assert_true(small.should_check_full(65))

  let wide = BloomFilter::with_size(4096, 1)
  // Walking 64 probes over 64 words is not yet worth a separate full scan.
  assert_false(wide.should_check_full(64))
  assert_true(wide.should_check_full(65))
  assert_true(wide.should_check_full(4096))
}
