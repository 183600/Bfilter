///|
test "cuckoo filter insert contains and remove" {
  let filter = @src.CuckooFilter::new(1000)
  assert_true(filter.is_empty())
  for i = 0; i < 1000; i = i + 1 {
    assert_true(filter.insert("key-" + i.to_string()))
  }
  assert_eq(filter.count(), 1000)
  for i = 0; i < 1000; i = i + 1 {
    assert_true(filter.contains("key-" + i.to_string()))
  }
  for i = 0; i < 1000; i = i + 1 {
    assert_true(filter.remove("key-" + i.to_string()))
  }
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
}

///|
test "cuckoo filter tracks duplicate insertions" {
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_true(filter.insert("same"))
  assert_true(filter.insert("same"))
  assert_eq(filter.count(), 2)
  assert_true(filter.remove("same"))
  assert_true(filter.contains("same"))
  assert_true(filter.remove("same"))
  assert_false(filter.contains("same"))
  assert_false(filter.remove("same"))
}

///|
test "cuckoo filter batch operations and clear" {
  let keys = ["a", "b", "c", "d"]
  let filter = @src.CuckooFilter::with_size(16, 4)
  assert_true(filter.insert_all(keys))
  assert_true(filter.contains_all(keys))
  assert_eq(filter.count(), 4)
  assert_true(filter.remove_all(keys))
  assert_true(filter.is_empty())
  ignore(filter.insert("a"))
  filter.clear()
  assert_true(filter.is_empty())
  assert_eq(filter.count(), 0)
  assert_false(filter.contains("a"))
}

///|
test "cuckoo filter rounds bucket count to a power of two" {
  let filter = @src.CuckooFilter::with_size(3, 2)
  assert_eq(filter.bucket_count(), 4)
  assert_eq(filter.bucket_size(), 2)
  assert_true(filter.insert("value"))
  assert_true(filter.contains("value"))
  assert_true(filter.remove("value"))
}

///|
test "cuckoo filter failed insert preserves existing entries" {
  let filter = @src.CuckooFilter::with_size(1, 1)
  assert_true(filter.insert("alpha"))
  assert_false(filter.insert("beta"))
  assert_eq(filter.count(), 1)
  assert_true(filter.contains("alpha"))
}

///|
test "cuckoo filter clear restores fresh insertion state" {
  let cleared = @src.CuckooFilter::with_size(4, 2)
  for i = 0; i < 8; i = i + 1 {
    assert_true(cleared.insert(11_000_000 + i))
  }
  for i = 0; i < 10; i = i + 1 {
    assert_false(cleared.insert(11_900_000 + i))
  }
  cleared.clear()
  let fresh = @src.CuckooFilter::with_size(4, 2)
  let keys = [
    11_000_042, 11_000_027, 11_000_056, 11_000_017, 11_000_054, 11_000_055, 11_000_036,
  ]
  for key in keys {
    assert_true(cleared.insert(key))
    assert_true(fresh.insert(key))
  }
  assert_eq(cleared.to_bytes(), fresh.to_bytes())
}

///|
test "cuckoo filter remove missing key returns false" {
  let filter = @src.CuckooFilter::new(10)
  assert_false(filter.remove("missing"))
  ignore(filter.insert("present"))
  assert_false(filter.remove("missing"))
  assert_true(filter.contains("present"))
}

///|
test "panic cuckoo filter rejects non-positive expected items" {
  @src.CuckooFilter::new(0) |> ignore
}

///|
test "panic cuckoo filter rejects non-positive bucket count" {
  @src.CuckooFilter::with_size(0, 4) |> ignore
}

///|
test "panic cuckoo filter rejects non-positive bucket size" {
  @src.CuckooFilter::with_size(4, 0) |> ignore
}

///|
test "cuckoo filter repeated failed inserts never lose entries" {
  let filter = @src.CuckooFilter::with_size(2, 1)
  let keys = ["a", "b", "c", "d", "e", "f", "g", "h"]
  let inserted : Array[String] = []
  for key in keys {
    if filter.insert(key) {
      inserted.push(key)
    }
  }
  assert_eq(filter.count(), inserted.length())
  for key in inserted {
    assert_true(filter.contains(key))
  }
}
