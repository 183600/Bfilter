///|
test "bloom probe cycle helper caps power-of-two bit arrays" {
  assert_eq(bloom_effective_probes(64, 2_147_483_647, 1UL), 64)
  assert_eq(bloom_effective_probes(64, 100, 2UL), 32)
  assert_eq(bloom_effective_probes(64, 100, 0UL), 1)
  assert_eq(bloom_effective_probes(64, 50, 1UL), 50)
  // Forty-eight words is not a power of two, so every probe still matters.
  assert_eq(bloom_effective_probes(192, 100, 1UL), 100)
}

///|
test "blocked probe cycle helper caps one 512-bit block" {
  assert_eq(blocked_effective_probes(2_147_483_647, 1UL), 512)
  assert_eq(blocked_effective_probes(1000, 2UL), 256)
  assert_eq(blocked_effective_probes(1000, 0UL), 1)
  assert_eq(blocked_effective_probes(100, 1UL), 100)
}

///|
test "non-power-of-two bloom probe walk matches a full reference" {
  // The cycle shortcut must not apply here: a 192-bit filter is not a power of
  // two, so every nominal hash position still has to be visited.
  let (h1, h2) = key_hashes("wide-nonpower")
  let expected = FixedArray::make(3, 0UL)
  let mut state = h1
  for i = 0; i < 300; i = i + 1 {
    let pos = (state % 192UL).to_int()
    expected[pos / 64] = expected[pos / 64] | (1UL << (pos % 64))
    state = state + h2
  }

  let filter = BloomFilter::with_size(192, 300)
  filter.insert_hashes(h1, h2)
  for i = 0; i < filter.words.length(); i = i + 1 {
    assert_eq(filter.words[i], expected[i])
  }
  assert_true(filter.contains_hashes(h1, h2))
  assert_false(filter.insert_if_absent_hashes(h1, h2))

  let conditional = BloomFilter::with_size(192, 300)
  assert_true(conditional.insert_if_absent_hashes(h1, h2))
  for i = 0; i < conditional.words.length(); i = i + 1 {
    assert_eq(conditional.words[i], expected[i])
  }
  assert_false(conditional.insert_if_absent_hashes(h1, h2))
}
