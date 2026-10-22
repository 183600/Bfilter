///|
test "serialized sizes match emitted byte lengths" {
  let bloom = BloomFilter::with_size(192, 4)
  bloom.insert_all(["alpha", "beta"])
  assert_eq(bloom.to_bytes().length(), bloom.serialized_size())
  assert_eq(bloom.to_bytes(), bloom.to_bytes())

  let counting = CountingBloomFilter::with_size(48, 3)
  counting.insert_all(["alpha", "beta", "alpha"])
  assert_eq(counting.to_bytes().length(), counting.serialized_size())
  assert_eq(counting.to_bytes(), counting.to_bytes())

  let scalable = ScalableBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    scalable.insert("key-" + i.to_string())
  }
  let mut scalable_size = SERIAL_HEADER_BYTES + 8
  for slice in scalable.slices {
    scalable_size = scalable_size + 4 + slice.serialized_size()
  }
  assert_eq(scalable.to_bytes().length(), scalable_size)
  assert_eq(scalable.to_bytes(), scalable.to_bytes())

  let scalable_counting = ScalableCountingBloomFilter::new(2, 0.01)
  for i = 0; i < 20; i = i + 1 {
    scalable_counting.insert("key-" + i.to_string())
  }
  let mut scalable_counting_size = SERIAL_HEADER_BYTES +
    12 +
    scalable_counting.locations.length() * 24
  for slice in scalable_counting.slices {
    scalable_counting_size = scalable_counting_size +
      4 +
      slice.serialized_size()
  }
  assert_eq(
    scalable_counting.to_bytes().length(),
    scalable_counting_size,
  )
  assert_eq(scalable_counting.to_bytes(), scalable_counting.to_bytes())
}
