#include "moonbit.h"

#if defined(_WIN32) || defined(_WIN64)
#include <windows.h>

typedef struct {
  CRITICAL_SECTION lock;
} bfilter_mutex_t;

static void bfilter_mutex_finalize(void *self) {
  bfilter_mutex_t *mutex = (bfilter_mutex_t *)self;
  DeleteCriticalSection(&mutex->lock);
}

MOONBIT_FFI_EXPORT
bfilter_mutex_t *bfilter_mutex_new(void) {
  bfilter_mutex_t *mutex = (bfilter_mutex_t *)moonbit_make_external_object(
      bfilter_mutex_finalize, sizeof(bfilter_mutex_t));
  InitializeCriticalSection(&mutex->lock);
  return mutex;
}

MOONBIT_FFI_EXPORT
void bfilter_mutex_acquire(bfilter_mutex_t *mutex) {
  EnterCriticalSection(&mutex->lock);
}

MOONBIT_FFI_EXPORT
void bfilter_mutex_release(bfilter_mutex_t *mutex) {
  LeaveCriticalSection(&mutex->lock);
}
#else
#include <pthread.h>

typedef struct {
  pthread_mutex_t lock;
} bfilter_mutex_t;

static void bfilter_mutex_finalize(void *self) {
  bfilter_mutex_t *mutex = (bfilter_mutex_t *)self;
  pthread_mutex_destroy(&mutex->lock);
}

MOONBIT_FFI_EXPORT
bfilter_mutex_t *bfilter_mutex_new(void) {
  bfilter_mutex_t *mutex = (bfilter_mutex_t *)moonbit_make_external_object(
      bfilter_mutex_finalize, sizeof(bfilter_mutex_t));
  pthread_mutex_init(&mutex->lock, NULL);
  return mutex;
}

MOONBIT_FFI_EXPORT
void bfilter_mutex_acquire(bfilter_mutex_t *mutex) {
  pthread_mutex_lock(&mutex->lock);
}

MOONBIT_FFI_EXPORT
void bfilter_mutex_release(bfilter_mutex_t *mutex) {
  pthread_mutex_unlock(&mutex->lock);
}
#endif
