// Simple test to verify MoonBit syntax

///|
test "simple_test" {
  let x = 1
  let y = 2
  assert_eq(x + y, 3)
}

///|
test "string_test" {
  let s = "hello"
  assert_eq(s.length(), 5)
}

///|
test "array_test" {
  let arr = Array::make(10, 0)
  assert_eq(arr.length(), 10)
}

///|
test "bool_test" {
  let b = true
  assert_true(b)
  assert_false(!b)
}
