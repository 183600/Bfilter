fn probe_count_only(filter : ScalableCountingBloomFilter, counts : Array[Int32], total : Int32) -> Unit {
  filter.slices = []
  filter.capacities = []
  filter.locations.clear()
  filter.inserted = 0
  filter.append_slice()
  for i = 1; i < counts.length(); i = i + 1 { filter.append_slice() }
  for i = 0; i < counts.length(); i = i + 1 {
    filter.slices[i].inserted = counts[i]
  }
  filter.inserted = total
}

fn probe_drained(filter : ScalableCountingBloomFilter, key : String, occurrences : Int32, slice : Int32) -> Unit {
  filter.slices = []
  filter.capacities = []
  filter.locations.clear()
  filter.inserted = 0
  filter.append_slice()
  for i = 1; i <= slice; i = i + 1 { filter.append_slice() }
  filter.locations.set(key_hashes(key), (slice, occurrences))
  filter.slices[slice].inserted = occurrences
  filter.inserted = occurrences
}

fn probe_roundtrip(filter : ScalableCountingBloomFilter) -> Unit raise {
  let bytes = filter.to_bytes()
  let restored = ScalableCountingBloomFilter::from_bytes(bytes)
  assert_eq(restored.to_bytes(), bytes)
  assert_eq(restored.count(), filter.count())
  assert_eq(restored.tracked_key_count(), filter.tracked_key_count())
  assert_eq(restored.occupied_slot_count(), filter.occupied_slot_count())
}

///|
test "scalable counting merge matrix keeps count-only and drained states serializable" {
  for receiver_slices = 1; receiver_slices <= 3; receiver_slices = receiver_slices + 1 {
    for source_slices = 1; source_slices <= 3; source_slices = source_slices + 1 {
      for mode = 0; mode < 4; mode = mode + 1 {
        let receiver = ScalableCountingBloomFilter::new(2, 0.5)
        let counts : Array[Int32] = Array::make(receiver_slices, 1)
        match mode {
          0 => probe_count_only(receiver, counts, receiver_slices)
          1 => probe_drained(receiver, "hot", 4465, receiver_slices - 1)
          2 => {
            receiver.clear()
            for i = 0; i < receiver_slices; i = i + 1 {
              if i > 0 { receiver.append_slice() }
              receiver.insert(i)
            }
          }
          _ => {
            receiver.clear()
            for i = 0; i < receiver_slices; i = i + 1 {
              if i > 0 { receiver.append_slice() }
              receiver.insert(i)
              receiver.insert(i)
            }
          }
        }
        let source = ScalableCountingBloomFilter::new(2, 0.5)
        match mode {
          0 => probe_count_only(source, Array::make(source_slices, 1), source_slices)
          1 => probe_drained(source, "cold", 3, source_slices - 1)
          2 => {
            source.clear()
            for i = 0; i < source_slices; i = i + 1 {
              if i > 0 { source.append_slice() }
              source.insert(100 + i)
            }
          }
          _ => {
            source.clear()
            for i = 0; i < source_slices; i = i + 1 {
              if i > 0 { source.append_slice() }
              source.insert(100 + i)
              source.insert(100 + i)
              source.insert(100 + i)
            }
          }
        }
        probe_roundtrip(receiver)
        probe_roundtrip(source)
        let combined = receiver.union(source)
        probe_roundtrip(combined)
        let merged = receiver.copy()
        merged.merge(source)
        assert_eq(merged.to_bytes(), combined.to_bytes())
        probe_roundtrip(merged)
        // A subsequent insertion and removal must keep the filter serializable.
        merged.insert("fresh")
        probe_roundtrip(merged)
        assert_eq(merged.count_of("fresh"), 1)
        assert_true(merged.contains("fresh"))
        assert_true(merged.remove("fresh"))
        probe_roundtrip(merged)
        let common = receiver.intersection(source)
        probe_roundtrip(common)
      }
    }
  }
}
