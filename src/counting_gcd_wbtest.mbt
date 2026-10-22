///|
/// Reference Euclidean implementation used to validate the optimized helper.
fn counting_gcd_reference(left : UInt64, right : UInt64) -> UInt64 {
  let mut a = left
  let mut b = right
  while b != 0UL {
    let remainder = a % b
    a = b
    b = remainder
  }
  a
}

///|
test "counting gcd fast path matches the Euclidean reference" {
  let samples : Array[(UInt64, UInt64)] = [
    (0UL, 0UL),
    (0UL, 1UL),
    (1UL, 0UL),
    (0UL, 1UL << 30),
    (1UL, 1UL << 30),
    (2UL, 1UL << 30),
    (3UL, 1UL << 30),
    (6UL, 16UL),
    (12UL, 16UL),
    (16UL, 16UL),
    (5UL, 48UL),
    (48UL, 5UL),
    (0xFFFFFFFFFFFFFFFFUL, 1UL << 63),
    (1UL << 63, 0xFFFFFFFFFFFFFFFFUL),
    (0xFFFFFFFFFFFFFFFFUL, 0xFFFFFFFFFFFFFFFFUL),
  ]
  for sample in samples {
    let (left, right) = sample
    assert_eq(counting_gcd(left, right), counting_gcd_reference(left, right))
  }

  for power = 0; power <= 40; power = power + 1 {
    let right = 1UL << power
    for offset = 0; offset < 64; offset = offset + 1 {
      let left = (offset.to_uint64() << 24) |
        (0x9E3779B97F4A7C15UL & (right - 1UL))
      assert_eq(counting_gcd(left, right), counting_gcd_reference(left, right))
      assert_eq(counting_gcd(right, right), right)
      assert_eq(counting_gcd(0UL, right), right)
    }
  }

  let mut seed = 0x12345678
  for round = 0; round < 512; round = round + 1 {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    let factor = if round % 2 == 0 {
      0x9E3779B97F4A7C15UL
    } else {
      1UL
    }
    let left = seed.to_uint64() * factor
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    let right = seed.to_uint64() | 1UL
    assert_eq(counting_gcd(left, right), counting_gcd_reference(left, right))
  }
}

///|
test "counting cycle length uses the fast power-of-two divisor" {
  // With an odd step the walk visits every slot, and with a step of four it
  // repeats after a quarter of the slots.
  assert_eq(counting_gcd(1UL, 16UL), 1UL)
  assert_eq(counting_gcd(4UL, 16UL), 4UL)
  assert_eq(counting_gcd(8UL, 16UL), 8UL)
  assert_eq(counting_gcd(16UL, 16UL), 16UL)
  assert_eq(counting_short_cycle_period(1UL, 16UL), 16)
  assert_eq(counting_short_cycle_period(4UL, 16UL), 4)
  assert_eq(counting_short_cycle_period(8UL, 16UL), 2)
  assert_eq(counting_short_cycle_period(16UL, 16UL), 1)
}
