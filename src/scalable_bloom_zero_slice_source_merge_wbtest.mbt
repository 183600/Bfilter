///|
fn zero_slice_bloom_source(
  initial_capacity : Int32,
  target_rate : Double,
  inserted : Int32,
) -> ScalableBloomFilter {
  {
    slices: [],
    capacities: [],
    initial_capacity,
    target_rate,
    inserted,
  }
}

///|
test "merging a zero-slice count-only source keeps its conservative count" {
  let receiver = ScalableBloomFilter::new(2, 0.01)
  let source = zero_slice_bloom_source(2, 0.01, 3)
  receiver.merge(source)
  assert_eq(receiver.count(), 3)
  assert_eq(receiver.slice_count(), 1)
  assert_eq(receiver.slices[0].inserted, 3)
  assert_eq(receiver.slices[0].set_bit_count(), 0)
  assert_false(receiver.contains("anything"))

  let restored = ScalableBloomFilter::from_bytes(receiver.to_bytes())
  assert_eq(restored.count(), 3)
  assert_eq(restored.slice_count(), 1)
  assert_eq(restored.slices[0].count(), 3)
  assert_false(restored.contains("anything"))
}

///|
test "zero-slice count-only merge keeps a grown empty receiver layout" {
  let receiver = ScalableBloomFilter::new(2, 0.01)
  receiver.append_slice()
  receiver.append_slice()
  let source = zero_slice_bloom_source(2, 0.01, 5)
  receiver.merge(source)
  assert_eq(receiver.count(), 5)
  assert_eq(receiver.slice_count(), 3)
  assert_eq(receiver.slices[0].inserted, 5)
  for i = 1; i < receiver.slice_count(); i = i + 1 {
    assert_eq(receiver.slices[i].inserted, 0)
  }
  assert_false(receiver.contains("anything"))

  let restored = ScalableBloomFilter::from_bytes(receiver.to_bytes())
  assert_eq(restored.count(), 5)
  assert_eq(restored.slice_count(), 3)
  assert_eq(restored.slices[0].count(), 5)
  assert_false(restored.contains("anything"))
}
