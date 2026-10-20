///|
/// JavaScript and WebAssembly backends execute modules on a single thread, so
/// the concurrency wrapper only needs an empty lock value there.
type Mutex = Unit

///|
fn mutex_new() -> Mutex {
  ()
}

///|
fn mutex_acquire(_mutex : Mutex) -> Unit {

}

///|
fn mutex_release(_mutex : Mutex) -> Unit {

}
