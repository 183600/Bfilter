///|
/// Sizing helpers shared by the Bloom filter family.
///
/// Every fixed-size filter derives its layout from the same two standard Bloom
/// filter formulas: the number of bits needed to reach a target
/// false-positive rate, and the number of hash functions that minimizes that
/// rate for the chosen bit count. The filters differ only in how they round
/// the resulting bit count to their own storage granularity.
///
/// The argument checks live here as well, so every filter reports the same
/// error for the same invalid input.

///|
/// Natural logarithm of 2.
const LN2 : Double = 0.6931471805599453

///|
/// Reject a non-positive expected item count.
///
/// Every sized constructor takes an expected item count, and a count of zero
/// or less cannot produce a meaningful layout.
fn validate_expected_items(expected_items : Int32) -> Unit {
  guard expected_items > 0 else { abort("expected_items must be positive") }
}

///|
/// Reject a target false-positive rate outside the open interval `(0, 1)`.
///
/// A rate of zero is unreachable in practice and a rate of one disables the
/// filter, so both are rejected.
fn validate_false_positive_rate(false_positive_rate : Double) -> Unit {
  guard false_positive_rate > 0.0 && false_positive_rate < 1.0 else {
    abort("false_positive_rate must be between 0 and 1")
  }
}

///|
/// Reject a non-positive hash count.
///
/// A filter without hash functions cannot select any position, so every
/// constructor requires at least one.
fn validate_hash_count(hash_count : Int32) -> Unit {
  guard hash_count > 0 else { abort("hash_count must be positive") }
}

///|
/// Number of bits a Bloom filter needs for `expected_items` keys and the
/// target `false_positive_rate`.
///
/// This is the standard `-n * ln(p) / (ln 2)^2` formula. The result is a
/// fractional bit count; each filter rounds it to its own storage granularity.
fn bloom_raw_bit_count(
  expected_items : Int32,
  false_positive_rate : Double,
) -> Double {
  let n = expected_items.to_double()
  -(n * @math.ln(false_positive_rate)) / (LN2 * LN2)
}

///|
/// Number of hash functions that minimizes the false-positive rate for a Bloom
/// filter with `raw_bit_count` bits.
///
/// This is the standard `round(-log2(p))` formula expressed in terms of the
/// bit count. The result is always at least one hash function.
fn bloom_hash_count(
  raw_bit_count : Double,
  expected_items : Int32,
) -> Int32 {
  let n = expected_items.to_double()
  (raw_bit_count / n * LN2).round().to_int().max(1)
}

///|
/// Round `value` up to the next multiple of `alignment`.
///
/// Every filter aligns its storage to a power of two so that counters pack
/// into whole words and blocked filters keep whole cache lines.
fn round_up_to_alignment(value : Int32, alignment : Int32) -> Int32 {
  (value + alignment - 1) / alignment * alignment
}

///|
/// Factor by which a growing filter enlarges the capacity of each new slice.
const SCALABLE_GROWTH : Int32 = 2

///|
/// False-positive rate assigned to slice `index` of a growing filter.
///
/// Every slice keeps half of the remaining budget, so the combined rate stays
/// bounded while the filter keeps accepting insertions. Halving a very small
/// target can underflow to zero, so the result is clamped to the smallest
/// positive double instead of falling back to the original target rate.
fn scalable_slice_rate(target_rate : Double, index : Int32) -> Double {
  let rate = target_rate * @math.pow(0.5, (index + 1).to_double())
  if rate > 0.0 {
    rate
  } else {
    0x0000000000000001L.reinterpret_as_double()
  }
}
