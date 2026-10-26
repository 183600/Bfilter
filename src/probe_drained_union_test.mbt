test "probe drained tracked union behavior" {
  let drained = @src.ScalableCountingBloomFilter::new(1, 0.5)
  for i = 0; i < 65536; i = i + 1 {
    drained.insert("hot")
  }
  for i = 0; i < 65535; i = i + 1 {
    assert_true(drained.remove("hot"))
  }
  assert_false(drained.contains("hot"))
  assert_eq(drained.count_of("hot"), 1)
  let other = @src.ScalableCountingBloomFilter::new(1, 0.5)
  other.insert("cold")
  let combined = drained.union(other)
  println("combined contains hot=" + combined.contains("hot").to_string() + " count_of=" + combined.count_of("hot").to_string() + " count=" + combined.count().to_string())
  println("restored contains hot=" + @src.ScalableCountingBloomFilter::from_bytes(combined.to_bytes()).contains("hot").to_string())
  let merged = drained.copy()
  merged.merge(other)
  println("merged contains hot=" + merged.contains("hot").to_string())
}
