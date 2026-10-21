///|
fn compact_mass(f : CompactCountingBloomFilter) -> UInt64 {
  let mut total = 0UL
  for word in f.counters {
    for lane = 0; lane < COMPACT_SLOTS_PER_WORD; lane = lane + 1 {
      total = total + ((word >> (lane * 4)) & COMPACT_COUNTER_MAX)
    }
  }
  total
}

///|
fn counting_mass(f : CountingBloomFilter) -> UInt64 {
  let mut total = 0UL
  for word in f.counters {
    for lane = 0; lane < 4; lane = lane + 1 {
      total = total + ((word >> (lane * 16)) & 0xFFFFUL)
    }
  }
  total
}

///|
test "probe compact shared saturation numbers" {
  let f = CompactCountingBloomFilter::with_size(16, 256)
  f.insert("left")
  println("after left: inserted=\{f.inserted} mass=\{compact_mass(f)} occupied=\{f.occupied_slot_count()}")
  f.insert("right")
  println("after right: inserted=\{f.inserted} mass=\{compact_mass(f)} occupied=\{f.occupied_slot_count()}")
  let r = f.remove("left")
  println("remove left=\{r}: inserted=\{f.inserted} mass=\{compact_mass(f)} occupied=\{f.occupied_slot_count()} contains-right=\{f.contains("right")}")
}

///|
test "probe compact serialization false positive numbers" {
  let f = CompactCountingBloomFilter::with_size(48, 720)
  f.insert(96)
  println("after insert: inserted=\{f.inserted} mass=\{compact_mass(f)} occupied=\{f.occupied_slot_count()}")
  let r = f.remove(251)
  println("remove 251=\{r}: inserted=\{f.inserted} mass=\{compact_mass(f)} occupied=\{f.occupied_slot_count()} k=\{f.hash_count}")
  println("k*inserted=\{f.hash_count.to_uint64() * f.inserted.to_uint64()}")
}

///|
test "probe counting serialization false positive numbers" {
  let f = CountingBloomFilter::with_size(48, 720)
  f.insert(96)
  println("after insert: inserted=\{f.inserted} mass=\{counting_mass(f)} occupied=\{f.occupied_slot_count()}")
  let r = f.remove(251)
  println("remove 251=\{r}: inserted=\{f.inserted} mass=\{counting_mass(f)} occupied=\{f.occupied_slot_count()} k=\{f.hash_count}")
  println("k*inserted=\{f.hash_count.to_uint64() * f.inserted.to_uint64()}")
}

///|
test "probe compact dup numbers" {
  let f = CompactCountingBloomFilter::with_size(48, 20)
  for i = 0; i < 8; i = i + 1 {
    f.insert("dup-3")
  }
  println("after 8 inserts: inserted=\{f.inserted} mass=\{compact_mass(f)} count_of=\{f.count_of("dup-3")}")
  for i = 0; i < 7; i = i + 1 {
    let r = f.remove("dup-3")
    println("remove \{i}: r=\{r} count=\{f.count()} count_of=\{f.count_of("dup-3")} contains=\{f.contains("dup-3")}")
  }
}

///|
test "probe key occurrence counts" {
  for config in [(16, 20), (16, 300), (48, 20), (16, 256), (48, 720)] {
    let (slots, k) = config
    for key in [0, 96, 251] {
      let (h1, h2) = key_hashes(key)
      let seen : Array[Int32] = []
      for j = 0; j < k; j = j + 1 {
        seen.push(bit_index(h1, h2, j, slots.to_uint64()))
      }
      let counts : Array[Int32] = []
      for pos = 0; pos < slots; pos = pos + 1 {
        let mut c = 0
        for p in seen {
          if p == pos {
            c = c + 1
          }
        }
        if c > 0 {
          counts.push(c)
        }
      }
      println("slots=\{slots} k=\{k} key=\{key} distinct=\{counts.length()} residues=\{counts.map(c => 65535 % c)}")
    }
  }
}

///|
test "zz invariant counter mass bounds inserted" {
  let layouts : Array[(Int32, Int32)] = [
    (16, 1),
    (16, 20),
    (48, 20),
    (16, 300),
    (48, 720),
    (256, 2),
  ]
  for layout in layouts {
    let (slots, k) = layout
    for round = 1; round <= 25; round = round + 1 {
      let compact = CompactCountingBloomFilter::with_size(slots, k)
      let counting = CountingBloomFilter::with_size(slots, k)
      let mut seed = round * 7919 + 3
      for step = 0; step < 200; step = step + 1 {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        let key = seed % 10
        let action = seed / 31 % 3
        if action == 0 {
          compact.insert(key)
          counting.insert(key)
        } else if action == 1 {
          ignore(compact.remove(key))
          ignore(counting.remove(key))
        } else {
          let restored_compact = CompactCountingBloomFilter::from_bytes(
            compact.to_bytes(),
          )
          assert_eq(restored_compact.count(), compact.count())
          let restored_counting = CountingBloomFilter::from_bytes(
            counting.to_bytes(),
          )
          assert_eq(restored_counting.count(), counting.count())
        }
        assert_true(
          compact_mass(compact) <= k.to_uint64() * compact.inserted.to_uint64(),
        )
        assert_true(
          counting_mass(counting) <= k.to_uint64() * counting.inserted.to_uint64(),
        )
      }
    }
  }
}
