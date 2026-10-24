///|
fn fill_bloom_until_full(filter : @src.BloomFilter) -> Unit {
  let mut index = 0
  while !filter.is_full() && index < 100_000 {
    filter.insert("bloom-fill-" + index.to_string())
    index = index + 1
  }
}

///|
fn fill_blocked_until_full(filter : @src.BlockedBloomFilter) -> Unit {
  let mut index = 0
  while !filter.is_full() && index < 100_000 {
    filter.insert("blocked-fill-" + index.to_string())
    index = index + 1
  }
}

///|
fn fill_counting_until_full(filter : @src.CountingBloomFilter) -> Unit {
  let mut index = 0
  while !filter.is_full() && index < 100_000 {
    filter.insert("counting-fill-" + index.to_string())
    index = index + 1
  }
}

///|
fn fill_compact_until_full(
  filter : @src.CompactCountingBloomFilter,
) -> Unit {
  let mut index = 0
  while !filter.is_full() && index < 100_000 {
    filter.insert("compact-fill-" + index.to_string())
    index = index + 1
  }
}

///|
test "fixed-size filters report full storage" {
  let bloom = @src.BloomFilter::with_size(64, 1)
  assert_false(bloom.is_full())
  fill_bloom_until_full(bloom)
  assert_true(bloom.is_full())
  let restored_bloom = @src.BloomFilter::from_bytes(bloom.to_bytes())
  assert_true(restored_bloom.is_full())
  bloom.clear()
  assert_false(bloom.is_full())

  let blocked = @src.BlockedBloomFilter::with_size(512, 1)
  assert_false(blocked.is_full())
  fill_blocked_until_full(blocked)
  assert_true(blocked.is_full())
  let restored_blocked = @src.BlockedBloomFilter::from_bytes(
    blocked.to_bytes(),
  )
  assert_true(restored_blocked.is_full())
  blocked.clear()
  assert_false(blocked.is_full())

  let counting = @src.CountingBloomFilter::with_size(16, 1)
  assert_false(counting.is_full())
  fill_counting_until_full(counting)
  assert_true(counting.is_full())
  let restored_counting = @src.CountingBloomFilter::from_bytes(
    counting.to_bytes(),
  )
  assert_true(restored_counting.is_full())
  counting.clear()
  assert_false(counting.is_full())

  let compact = @src.CompactCountingBloomFilter::with_size(16, 1)
  assert_false(compact.is_full())
  fill_compact_until_full(compact)
  assert_true(compact.is_full())
  let restored_compact = @src.CompactCountingBloomFilter::from_bytes(
    compact.to_bytes(),
  )
  assert_true(restored_compact.is_full())
  compact.clear()
  assert_false(compact.is_full())
}

///|
test "concurrent fixed-size filters report full storage" {
  let bloom = @src.ConcurrentBloomFilter::with_size(64, 1)
  assert_false(bloom.is_full())
  let mut index = 0
  while !bloom.is_full() && index < 100_000 {
    bloom.insert("concurrent-bloom-fill-" + index.to_string())
    index = index + 1
  }
  assert_true(bloom.is_full())
  bloom.clear()
  assert_false(bloom.is_full())

  let blocked = @src.ConcurrentBlockedBloomFilter::with_size(512, 1)
  assert_false(blocked.is_full())
  index = 0
  while !blocked.is_full() && index < 100_000 {
    blocked.insert("concurrent-blocked-fill-" + index.to_string())
    index = index + 1
  }
  assert_true(blocked.is_full())
  blocked.clear()
  assert_false(blocked.is_full())

  let counting = @src.ConcurrentCountingBloomFilter::with_size(16, 1)
  assert_false(counting.is_full())
  index = 0
  while !counting.is_full() && index < 100_000 {
    counting.insert("concurrent-counting-fill-" + index.to_string())
    index = index + 1
  }
  assert_true(counting.is_full())
  counting.clear()
  assert_false(counting.is_full())

  let compact = @src.ConcurrentCompactCountingBloomFilter::with_size(16, 1)
  assert_false(compact.is_full())
  index = 0
  while !compact.is_full() && index < 100_000 {
    compact.insert("concurrent-compact-fill-" + index.to_string())
    index = index + 1
  }
  assert_true(compact.is_full())
  compact.clear()
  assert_false(compact.is_full())
}
