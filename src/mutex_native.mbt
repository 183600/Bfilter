///|
/// A native operating-system mutex used by `ConcurrentBloomFilter`.
type Mutex

///|
extern "C" fn mutex_new() -> Mutex = "bfilter_mutex_new"

///|
#borrow(mutex)
extern "C" fn mutex_acquire(mutex : Mutex) -> Unit = "bfilter_mutex_acquire"

///|
#borrow(mutex)
extern "C" fn mutex_release(mutex : Mutex) -> Unit = "bfilter_mutex_release"
