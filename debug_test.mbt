import {
  "183600/bfilter/src" @src,
}

fn main raise {
  let filter = @src.BloomFilter::new(1000, 0.01)
  print("is_empty: ", filter.is_empty())
  print("inserted: ", filter.inserted)
  print("count: ", filter.count())
}
