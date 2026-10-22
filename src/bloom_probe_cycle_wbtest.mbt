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
