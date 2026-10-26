///|
fn audit_set_seed(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7FFFFFFF
}

///|
test "audit scalable set check safety" {
  for round = 1; round <= 200; round = round + 1 {
    let left = @src.ScalableBloomFilter::new(2, 0.3)
    let right = @src.ScalableBloomFilter::new(2, 0.3)
    let left_count = @src.ScalableCountingBloomFilter::new(2, 0.3)
    let right_count = @src.ScalableCountingBloomFilter::new(2, 0.3)
    let mut seed = round * 7919 + 13
    for step = 0; step < 200; step = step + 1 {
      seed = audit_set_seed(seed)
      let key = seed % 40
      let which = seed / 31 % 6
      if which == 0 {
        left.insert(key)
        left_count.insert(key)
      } else if which == 1 {
        right.insert(key)
        right_count.insert(key)
      } else if which == 2 {
        ignore(left_count.remove(key))
      } else if which == 3 {
        ignore(right_count.remove(key))
      } else if which == 4 {
        let filter = left.union(right)
        let combined = left_count.union(right_count)
        for k = 0; k < 40; k = k + 1 {
          if left.contains(k) || right.contains(k) {
            assert_true(filter.contains(k))
          }
          if (left_count.count_of(k) > 0 || right_count.count_of(k) > 0) &&
            (left_count.contains(k) || right_count.contains(k)) {
            if !combined.contains(k) {
              println("union miss round=" + round.to_string() + " step=" + step.to_string() + " key=" + k.to_string() + " left=" + left_count.contains(k).to_string() + " right=" + right_count.contains(k).to_string() + " lc=" + left_count.count_of(k).to_string() + " rc=" + right_count.count_of(k).to_string() + " cc=" + combined.count_of(k).to_string())
              abort("union miss")
            }
          }
        }
      } else {
        let filter = left.intersection(right)
        let common = left_count.intersection(right_count)
        for k = 0; k < 40; k = k + 1 {
          if left_count.count_of(k) > 0 && right_count.count_of(k) > 0 &&
            left_count.contains(k) && right_count.contains(k) {
            if !common.contains(k) {
              println("intersection miss round=" + round.to_string() + " step=" + step.to_string() + " key=" + k.to_string() + " lc=" + left_count.count_of(k).to_string() + " rc=" + right_count.count_of(k).to_string() + " cc=" + common.count_of(k).to_string())
              abort("intersection miss")
            }
          }
        }
      }
    }
    if left.is_subset_of(right) {
      for k = 0; k < 40; k = k + 1 {
        if left.contains(k) {
          assert_true(right.contains(k))
        }
      }
    }
    if right.is_subset_of(left) {
      for k = 0; k < 40; k = k + 1 {
        if right.contains(k) {
          assert_true(left.contains(k))
        }
      }
    }
    if left.is_disjoint_from(right) {
      for k = 0; k < 40; k = k + 1 {
        assert_false(left.contains(k) && right.contains(k))
      }
    }
    if left_count.is_subset_of(right_count) {
      for k = 0; k < 40; k = k + 1 {
        if left_count.contains(k) {
          assert_true(right_count.contains(k))
        }
      }
    }
    if right_count.is_subset_of(left_count) {
      for k = 0; k < 40; k = k + 1 {
        if right_count.contains(k) {
          assert_true(left_count.contains(k))
        }
      }
    }
    if left_count.is_disjoint_from(right_count) {
      for k = 0; k < 40; k = k + 1 {
        assert_false(left_count.contains(k) && right_count.contains(k))
      }
    }
  }
}
