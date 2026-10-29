///|
fn main raise {
  let expected_items = 5_000
  let target_rate = 0.01
  let filter = @src.BloomFilter::new(expected_items, target_rate)
  let inserted : Array[String] = Array::makei(
    expected_items,
    i => "user-" + i.to_string(),
  )
  filter.insert_all(inserted)
  let all_present = filter.contains_all(inserted)
  let representative = ["user-0", "user-2500", "user-4999"]
  let representative_present = filter.contains_all(representative)
  let absent : Array[String] = Array::makei(
    10_000,
    i => "absent-" + i.to_string(),
  )
  let mut false_positives = 0
  for key in absent {
    if filter.contains(key) {
      false_positives = false_positives + 1
    }
  }
  let observed_rate = false_positives.to_double() / absent.length().to_double()
  println("inserted=" + expected_items.to_string())
  println("contains_all_inserted=" + all_present.to_string())
  println("contains_representative=" + representative_present.to_string())
  println("queried_absent=" + absent.length().to_string())
  println("false_positives=" + false_positives.to_string())
  println("configured_false_positive_rate=" + target_rate.to_string())
  println(
    "estimated_false_positive_rate=" + filter.false_positive_rate().to_string(),
  )
  println("observed_false_positive_rate=" + observed_rate.to_string())
  assert_true(all_present)
  assert_true(representative_present)
  assert_true(observed_rate < 0.03)

  let bytes = filter.to_bytes()
  let restored = @src.BloomFilter::from_bytes(bytes)
  let equivalent = restored.bit_count() == filter.bit_count() &&
    restored.hash_count() == filter.hash_count() &&
    restored.count() == filter.count() &&
    restored.set_bit_count() == filter.set_bit_count() &&
    restored.contains_all(inserted) &&
    restored.to_bytes() == bytes
  println("serialized_bytes=" + bytes.length().to_string())
  println("deserialize_equivalent=" + equivalent.to_string())
  assert_true(equivalent)
}
