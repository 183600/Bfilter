///|
let bench_keys : Array[String] = Array::makei(1000, i => "key-" + i.to_string())

///|
test "bench bloom insert n=1000" (b : @bench.T) {
  let filter = @src.BloomFilter::new(1000, 0.01)
  let mut index = 0
  b.bench(fn() {
    filter.insert(bench_keys[index])
    index = (index + 1) % bench_keys.length()
    b.keep(filter)
  })
}

///|
test "bench bloom contains n=1000" (b : @bench.T) {
  let filter = @src.BloomFilter::new(1000, 0.01)
  filter.insert_all(bench_keys)
  let mut index = 0
  let mut hits = 0
  b.bench(fn() {
    if filter.contains(bench_keys[index]) {
      hits = hits + 1
    }
    index = (index + 1) % bench_keys.length()
    b.keep(hits)
  })
}

///|
test "bench bloom insert_all n=1000" (b : @bench.T) {
  let filter = @src.BloomFilter::new(1000, 0.01)
  b.bench(fn() {
    filter.clear()
    filter.insert_all(bench_keys)
    b.keep(filter)
  })
}

///|
test "bench counting insert_remove n=1000" (b : @bench.T) {
  let filter = @src.CountingBloomFilter::new(1000, 0.01)
  let mut index = 0
  let mut removed = 0
  b.bench(fn() {
    let key = bench_keys[index]
    filter.insert(key)
    if filter.remove(key) {
      removed = removed + 1
    }
    index = (index + 1) % bench_keys.length()
    b.keep(removed)
  })
}

///|
test "bench counting contains n=1000" (b : @bench.T) {
  let filter = @src.CountingBloomFilter::new(1000, 0.01)
  filter.insert_all(bench_keys)
  let mut index = 0
  let mut hits = 0
  b.bench(fn() {
    if filter.contains(bench_keys[index]) {
      hits = hits + 1
    }
    index = (index + 1) % bench_keys.length()
    b.keep(hits)
  })
}

///|
test "bench cuckoo insert_remove n=1000" (b : @bench.T) {
  let filter = @src.CuckooFilter::new(1000)
  let mut index = 0
  let mut removed = 0
  b.bench(fn() {
    let key = bench_keys[index]
    ignore(filter.insert(key))
    if filter.remove(key) {
      removed = removed + 1
    }
    index = (index + 1) % bench_keys.length()
    b.keep(removed)
  })
}

///|
test "bench cuckoo contains n=1000" (b : @bench.T) {
  let filter = @src.CuckooFilter::new(1000)
  ignore(filter.insert_all(bench_keys))
  let mut index = 0
  let mut hits = 0
  b.bench(fn() {
    if filter.contains(bench_keys[index]) {
      hits = hits + 1
    }
    index = (index + 1) % bench_keys.length()
    b.keep(hits)
  })
}

///|
test "bench concurrent contains n=1000" (b : @bench.T) {
  let filter = @src.ConcurrentBloomFilter::new(1000, 0.01)
  filter.insert_all(bench_keys)
  let mut index = 0
  let mut hits = 0
  b.bench(fn() {
    if filter.contains(bench_keys[index]) {
      hits = hits + 1
    }
    index = (index + 1) % bench_keys.length()
    b.keep(hits)
  })
}

///|
test "bench bloom union n=1000" (b : @bench.T) {
  let left = @src.BloomFilter::new(1000, 0.01)
  let right = @src.BloomFilter::new(1000, 0.01)
  left.insert_all(bench_keys)
  right.insert_all(bench_keys)
  b.bench(fn() {
    let combined = left.union(right)
    b.keep(combined)
  })
}

///|
test "bench counting union n=1000" (b : @bench.T) {
  let left = @src.CountingBloomFilter::new(1000, 0.01)
  let right = @src.CountingBloomFilter::new(1000, 0.01)
  left.insert_all(bench_keys)
  right.insert_all(bench_keys)
  b.bench(fn() {
    let combined = left.union(right)
    b.keep(combined)
  })
}

///|
test "bench cuckoo union n=1000" (b : @bench.T) {
  let left = @src.CuckooFilter::new(1000)
  let right = @src.CuckooFilter::new(1000)
  ignore(left.insert_all(bench_keys))
  ignore(right.insert_all(bench_keys))
  b.bench(fn() {
    let combined = left.union(right)
    b.keep(combined)
  })
}
