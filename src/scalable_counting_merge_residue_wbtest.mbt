///|
fn merge_residue_key_with_repeats(
  filter : ScalableCountingBloomFilter,
) -> String {
  for i = 0; i < 10000; i = i + 1 {
    let key = "merge-residue-" + i.to_string()
    let id = key_hashes(key)
    let slice = filter.slices[0]
    let positions = unique_key_positions_fast(
      id.0,
      id.1,
      slice.hash_count,
      slice.slot_count.to_uint64(),
    )
    let mut minimum = 100000
    let mut maximum = 0
    for j = 0; j < positions.length; j = j + 1 {
      if positions.counts[j] < minimum {
        minimum = positions.counts[j]
      }
      if positions.counts[j] > maximum {
        maximum = positions.counts[j]
      }
    }
    if minimum != maximum && maximum >= 2 {
      return key
    }
  }
  abort("no key with repeated probe positions")
}

///|
fn merge_residue_key_with_repeats_avoiding(
  filter : ScalableCountingBloomFilter,
  blocked : FixedArray[Bool],
) -> String {
  for i = 0; i < 10000; i = i + 1 {
    let key = "merge-residue-" + i.to_string()
    let id = key_hashes(key)
    let slice = filter.slices[0]
    let positions = unique_key_positions_fast(
      id.0,
      id.1,
      slice.hash_count,
      slice.slot_count.to_uint64(),
    )
    let mut usable = true
    let mut minimum = 100000
    let mut maximum = 0
    for j = 0; j < positions.length; j = j + 1 {
      if blocked[positions.positions[j]] {
        usable = false
      }
      if positions.counts[j] < minimum {
        minimum = positions.counts[j]
      }
      if positions.counts[j] > maximum {
        maximum = positions.counts[j]
      }
    }
    if usable && minimum != maximum && maximum >= 2 {
      return key
    }
  }
  abort("no disjoint key with repeated probe positions")
}

///|
/// A merged key with repeated probe positions has lanes with different removable
/// caps. Rebuilding such a key lane by lane can saturate one lane before the
/// others, so removal stops with positive residue that no later removal of the
/// key can drain. The rebuilt slice must advance all lanes together instead.
test "scalable counting merge drains multiplied keys without residue" {
  let target = ScalableCountingBloomFilter::new(1, 1.0e-8)
  target.insert("target-key")
  let baseline = target.copy()
  let blocked : FixedArray[Bool] = FixedArray::make(
    target.slices[0].slot_count,
    false,
  )
  let target_id = key_hashes("target-key")
  let target_positions = unique_key_positions_fast(
    target_id.0,
    target_id.1,
    target.slices[0].hash_count,
    target.slices[0].slot_count.to_uint64(),
  )
  for i = 0; i < target_positions.length; i = i + 1 {
    blocked[target_positions.positions[i]] = true
  }
  let source = ScalableCountingBloomFilter::new(1, 1.0e-8)
  let key = merge_residue_key_with_repeats_avoiding(source, blocked)
  for i = 0; i < 40000; i = i + 1 {
    source.insert(key)
  }
  let id = key_hashes(key)
  let source_slice = source.slices[0]
  let positions = unique_key_positions_fast(
    id.0,
    id.1,
    source_slice.hash_count,
    source_slice.slot_count.to_uint64(),
  )
  let mut removable = 100000UL
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    let occurrences = positions.counts[i].to_uint64()
    let limit = counting_position_limit(occurrences)
    let base = baseline.slices[0].counter_at(pos)
    let available = if base > limit {
      0UL
    } else {
      (limit - base) / occurrences
    }
    if available < removable {
      removable = available
    }
  }
  assert_true(removable > 0UL)
  target.merge(source)
  assert_eq(target.count_of(key), 40000)
  let mut removed = 0
  while target.remove(key) {
    removed = removed + 1
  }
  assert_eq(removed.to_uint64(), removable)
  assert_eq(target.count_of(key), 40000 - removable.to_int())
  for i = 0; i < positions.length; i = i + 1 {
    let pos = positions.positions[i]
    assert_eq(
      target.slices[0].counter_at(pos),
      baseline.slices[0].counter_at(pos),
    )
  }
  let restored = ScalableCountingBloomFilter::from_bytes(target.to_bytes())
  assert_eq(restored.count(), target.count())
  assert_eq(restored.count_of(key), target.count_of(key))
}

///|
/// Intersection rebuilds every surviving key into a fresh slice, so a key with
/// repeated probe positions must advance its lanes together there as well.
test "scalable counting intersection drains multiplied keys without residue" {
  let left = ScalableCountingBloomFilter::new(1, 1.0e-8)
  let right = ScalableCountingBloomFilter::new(1, 1.0e-8)
  let key = merge_residue_key_with_repeats(left)
  for i = 0; i < 40000; i = i + 1 {
    left.insert(key)
    right.insert(key)
  }
  let id = key_hashes(key)
  let positions = unique_key_positions_fast(
    id.0,
    id.1,
    left.slices[0].hash_count,
    left.slices[0].slot_count.to_uint64(),
  )
  let mut removable = 100000UL
  for i = 0; i < positions.length; i = i + 1 {
    let occurrences = positions.counts[i].to_uint64()
    let available = counting_position_limit(occurrences) / occurrences
    if available < removable {
      removable = available
    }
  }
  assert_true(removable > 0UL)
  let common = left.intersection(right)
  assert_eq(common.count_of(key), 40000)
  let mut removed = 0
  while common.remove(key) {
    removed = removed + 1
  }
  assert_eq(removed.to_uint64(), removable)
  assert_eq(common.count_of(key), 40000 - removable.to_int())
  for i = 0; i < positions.length; i = i + 1 {
    assert_eq(common.slices[0].counter_at(positions.positions[i]), 0UL)
  }
  let restored = ScalableCountingBloomFilter::from_bytes(common.to_bytes())
  assert_eq(restored.count(), common.count())
  assert_eq(restored.count_of(key), common.count_of(key))
}

///|
/// When both inputs track the same key in the same slice, the merged counter
/// must represent the larger multiplicity once. Raising the receiver's copies
/// and then the source's extra copies separately can overfill repeated
/// positions beyond their removable cap.
test "scalable counting same-slice merge drains multiplied key without residue" {
  let target = ScalableCountingBloomFilter::new(1, 1.0e-8)
  let source = ScalableCountingBloomFilter::new(1, 1.0e-8)
  let key = merge_residue_key_with_repeats(target)
  target.insert(key)
  for i = 0; i < 40000; i = i + 1 {
    source.insert(key)
  }
  let id = key_hashes(key)
  let positions = unique_key_positions_fast(
    id.0,
    id.1,
    target.slices[0].hash_count,
    target.slices[0].slot_count.to_uint64(),
  )
  let mut removable = 100000UL
  for i = 0; i < positions.length; i = i + 1 {
    let occurrences = positions.counts[i].to_uint64()
    let available = counting_position_limit(occurrences) / occurrences
    if available < removable {
      removable = available
    }
  }
  assert_true(removable > 0UL)
  target.merge(source)
  assert_eq(target.count_of(key), 40000)
  let mut removed = 0
  while target.remove(key) {
    removed = removed + 1
  }
  assert_eq(removed.to_uint64(), removable)
  assert_eq(target.count_of(key), 40000 - removable.to_int())
  for i = 0; i < positions.length; i = i + 1 {
    assert_eq(target.slices[0].counter_at(positions.positions[i]), 0UL)
  }
  let restored = ScalableCountingBloomFilter::from_bytes(target.to_bytes())
  assert_eq(restored.count(), target.count())
  assert_eq(restored.count_of(key), target.count_of(key))
}
