///|
test "blocked full-filter shortcut follows the block and word widths" {
  let one_block = BlockedBloomFilter::with_size(512, 1)
  assert_eq(one_block.block_count(), 1)
  assert_false(one_block.should_check_full(64))
  assert_true(one_block.should_check_full(65))

  // A large blocked layout touches at most 512 probes, so a much longer
  // nominal hash count does not justify scanning its whole word array.
  let many_blocks = BlockedBloomFilter::with_size(512 * 128, 1)
  assert_false(many_blocks.should_check_full(512))
  assert_true(many_blocks.should_check_full(2000))
}
