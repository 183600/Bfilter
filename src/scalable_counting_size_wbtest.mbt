///|
test "scalable counting accepts counter layouts beyond the old bit budget" {
  // This layout needs 134_219_104 counter slots. The previous guard compared
  // slot_count * 16 against the Bloom bit budget and rejected it even though
  // the backing counter array is only about 268 MB, well within the counting
  // filter's supported storage.
  let (slots, _) = CountingBloomFilter::optimal_size(93_353, 1.0e-300)
  assert_true(slots.to_int64() > 134_217_724L)
  assert_true(slots.to_int64() <= SCALABLE_COUNTING_MAX_SLOTS)
}

///|
test "scalable counting size budget leaves room for every slice header" {
  assert_eq(SCALABLE_COUNTING_MAX_SLOTS, 1_073_741_435L)
  assert_true(
    SERIAL_HEADER_BYTES.to_int64() +
    12L +
    31L * (SERIAL_HEADER_BYTES.to_int64() + 4L) +
    SCALABLE_COUNTING_MAX_SLOTS * 2L <=
    2_147_483_647L,
  )
}

///|
test "scalable counting maximum slot budget fits the largest slice layout" {
  // Slot counts are multiples of 16, so the usable maximum is the largest
  // multiple that fits the budget. Include the inner counting-filter header of
  // every slice, not just the length prefix.
  let max_slots = SCALABLE_COUNTING_MAX_SLOTS / 16L * 16L
  let serialized_size = SERIAL_HEADER_BYTES.to_int64() +
    12L +
    31L * (SERIAL_HEADER_BYTES.to_int64() + 4L) +
    max_slots * 2L
  assert_true(serialized_size <= 2_147_483_647L)
}
