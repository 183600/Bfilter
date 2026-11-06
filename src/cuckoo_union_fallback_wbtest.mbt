///|
test "scratch explore cuckoo union fallback" {
  // Randomized search for a configuration where the forward union placement
  // fails but the reversed one succeeds.
  let mut found_backward = false
  let mut found_retry = false
  let mut forward_failures = 0
  let mut state = 0x9E3779B97F4A7C15UL
  for iteration = 0; iteration < 20000; iteration = iteration + 1 {
    state = state * 6364136223846793005UL + 1442695040888963407UL
    let bucket_count = 2 << (state % 8UL).to_int()
    state = state * 6364136223846793005UL + 1442695040888963407UL
    let bucket_size = 1 + (state % 4UL).to_int()
    let capacity = bucket_count * bucket_size
    state = state * 6364136223846793005UL + 1442695040888963407UL
    let left_n = 1 + (state % (capacity - 1).to_uint64()).to_int()
    state = state * 6364136223846793005UL + 1442695040888963407UL
    let right_n = 1 + (state % (capacity - left_n).to_uint64()).to_int()
    let left = CuckooFilter::with_size(bucket_count, bucket_size)
    let right = CuckooFilter::with_size(bucket_count, bucket_size)
    left.random_state = mix64(state ^ 0x1234567890ABCDEFUL) | 1UL
    right.random_state = mix64(state ^ 0x0FEDCBA987654321UL) | 1UL
    let mut ok = true
    for i = 0; i < left_n; i = i + 1 {
      state = state * 6364136223846793005UL + 1442695040888963407UL
      if !left.insert("l" + state.to_string()) {
        ok = false
        break
      }
    }
    if !ok {
      continue
    }
    for i = 0; i < right_n; i = i + 1 {
      state = state * 6364136223846793005UL + 1442695040888963407UL
      if !right.insert("r" + state.to_string()) {
        ok = false
        break
      }
    }
    if !ok {
      continue
    }
    if left.try_union_with(right) is Some(_) {
      continue
    }
    forward_failures = forward_failures + 1
    if !found_backward && right.try_union_with(left) is Some(_) {
      println(
        "BACKWARD buckets=" +
        bucket_count.to_string() +
        " size=" +
        bucket_size.to_string() +
        " left=" +
        left_n.to_string() +
        " right=" +
        right_n.to_string(),
      )
      found_backward = true
    }
    if !found_retry && CuckooFilter::retry_union(left, right) is Some(_) {
      println(
        "RETRY buckets=" +
        bucket_count.to_string() +
        " size=" +
        bucket_size.to_string() +
        " left=" +
        left_n.to_string() +
        " right=" +
        right_n.to_string(),
      )
      found_retry = true
    }
    if found_backward && found_retry {
      break
    }
  }
  println(
    "forward failures=" +
    forward_failures.to_string() +
    " backward=" +
    found_backward.to_string() +
    " retry=" +
    found_retry.to_string(),
  )
}
