/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2014 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#include "xenia/base/threading.h"

#include "xenia/base/assert.h"
#include "xenia/base/logging.h"

#include <mach/mach.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

namespace xe {
namespace threading {

void EnableAffinityConfiguration() {}

uint32_t current_thread_system_id() {
  mach_port_t tid = pthread_mach_thread_np(pthread_self());
  return static_cast<uint32_t>(tid);
}

void set_name(const std::string& name) { pthread_setname_np(name.c_str()); }

void set_name(std::thread::native_handle_type handle, const std::string& name) {
  // ?
}

void MaybeYield() {
  pthread_yield_np();
  __sync_synchronize();
}

void SyncMemory() { __sync_synchronize(); }

void Sleep(std::chrono::microseconds duration) {
  timespec rqtp = {duration.count() / 1000000, duration.count() % 1000};
  nanosleep(&rqtp, nullptr);
  // TODO(benvanik): spin while rmtp >0?
}

// TODO(dougvj) Not sure how to implement the equivalent of this on POSIX.
SleepResult AlertableSleep(std::chrono::microseconds duration) {
  sleep(duration.count() / 1000);
  return SleepResult::kSuccess;
}

// TODO(dougvj) We can probably wrap this with pthread_key_t but the type of
// TlsHandle probably needs to be refactored
TlsHandle AllocateTlsHandle() {
  assert_always();
  return 0;
}

bool FreeTlsHandle(TlsHandle handle) { return true; }

uintptr_t GetTlsValue(TlsHandle handle) {
  assert_always();
  return 0;
}

bool SetTlsValue(TlsHandle handle, uintptr_t value) {
  assert_always();
  return false;
}

// TODO(dougvj)
class MacHighResolutionTimer : public HighResolutionTimer {
 public:
  MacHighResolutionTimer(std::function<void()> callback)
      : callback_(callback) {}
  ~MacHighResolutionTimer() override {}

  bool Initialize(std::chrono::milliseconds period) {
    assert_always();
    return false;
  }

 private:
  std::function<void()> callback_;
};

std::unique_ptr<HighResolutionTimer> HighResolutionTimer::CreateRepeating(
    std::chrono::milliseconds period, std::function<void()> callback) {
  auto timer = std::make_unique<MacHighResolutionTimer>(std::move(callback));
  if (!timer->Initialize(period)) {
    return nullptr;
  }
  return std::unique_ptr<HighResolutionTimer>(timer.release());
}

// TODO(dougvj) There really is no native POSIX handle for a single wait/signal
// construct pthreads is at a lower level with more handles for such a mechanism
// This simple wrapper class could function as our handle, but probably needs
// some more functionality
class MacCondition {
 public:
  MacCondition() : signal_(false) {
    pthread_mutex_init(&mutex_, NULL);
    pthread_cond_init(&cond_, NULL);
  }

  ~MacCondition() {
    pthread_mutex_destroy(&mutex_);
    pthread_cond_destroy(&cond_);
  }

  void Signal() {
    pthread_mutex_lock(&mutex_);
    signal_ = true;
    pthread_cond_broadcast(&cond_);
    pthread_mutex_unlock(&mutex_);
  }

  void Reset() {
    pthread_mutex_lock(&mutex_);
    signal_ = false;
    pthread_mutex_unlock(&mutex_);
  }

  bool Wait(unsigned int timeout_ms) {
    // Assume 0 means no timeout, not instant timeout
    if (timeout_ms == 0) {
      Wait();
    }
    struct timespec time_to_wait;
    struct timeval now;
    gettimeofday(&now, NULL);

    // Add the number of seconds we want to wait to the current time
    time_to_wait.tv_sec = now.tv_sec + (timeout_ms / 1000);
    // Add the number of nanoseconds we want to wait to the current nanosecond
    // stride
    long nsec = (now.tv_usec + (timeout_ms % 1000)) * 1000;
    // If we overflowed the nanosecond count then we add a second
    time_to_wait.tv_sec += nsec / 1000000000UL;
    // We only add nanoseconds within the 1 second stride
    time_to_wait.tv_nsec = nsec % 1000000000UL;
    pthread_mutex_lock(&mutex_);
    while (!signal_) {
      int status = pthread_cond_timedwait(&cond_, &mutex_, &time_to_wait);
      if (status == ETIMEDOUT) return false;  // We timed out
    }
    pthread_mutex_unlock(&mutex_);
    return true;  // We didn't time out
  }

  bool Wait() {
    pthread_mutex_lock(&mutex_);
    while (!signal_) {
      pthread_cond_wait(&cond_, &mutex_);
    }
    pthread_mutex_unlock(&mutex_);
    return true;  // Did not time out;
  }

 private:
  bool signal_;
  pthread_cond_t cond_;
  pthread_mutex_t mutex_;
};

// Native posix thread handle
template <typename T>
class MacThreadHandle : public T {
 public:
  explicit MacThreadHandle(pthread_t handle) : handle_(handle) {}
  ~MacThreadHandle() override {}

 protected:
  void* native_handle() const override {
    return reinterpret_cast<void*>(handle_);
  }

  pthread_t handle_;
};

// This is wraps a condition object as our handle because posix has no single
// native handle for higher level concurrency constructs such as semaphores
template <typename T>
class MacConditionHandle : public T {
 public:
  ~MacConditionHandle() override {}

 protected:
  void* native_handle() const override {
    return reinterpret_cast<void*>(const_cast<MacCondition*>(&handle_));
  }

  MacCondition handle_;
};

// TODO(dougvj)
WaitResult Wait(WaitHandle* wait_handle, bool is_alertable,
                std::chrono::milliseconds timeout) {
  intptr_t handle = reinterpret_cast<intptr_t>(wait_handle->native_handle());

  fd_set set;
  struct timeval time_val;
  int ret;

  FD_ZERO(&set);
  FD_SET(handle, &set);

  time_val.tv_sec = timeout.count() / 1000;
  time_val.tv_usec = timeout.count() * 1000;
  ret = select(handle + 1, &set, NULL, NULL, &time_val);
  if (ret == -1) {
    return WaitResult::kFailed;
  } else if (ret == 0) {
    return WaitResult::kTimeout;
  } else {
    uint64_t buf = 0;
    ret = read(handle, &buf, sizeof(buf));
    if (ret < 8) {
      return WaitResult::kTimeout;
    }

    return WaitResult::kSuccess;
  }
}

// TODO(dougvj)
WaitResult SignalAndWait(WaitHandle* wait_handle_to_signal,
                         WaitHandle* wait_handle_to_wait_on, bool is_alertable,
                         std::chrono::milliseconds timeout) {
  assert_always();
  return WaitResult::kFailed;
}

// TODO(dougvj)
std::pair<WaitResult, size_t> WaitMultiple(WaitHandle* wait_handles[],
                                           size_t wait_handle_count,
                                           bool wait_all, bool is_alertable,
                                           std::chrono::milliseconds timeout) {
  assert_always();
  return std::pair<WaitResult, size_t>(WaitResult::kFailed, 0);
}

std::unique_ptr<Event> Event::CreateManualResetEvent(bool initial_state) {
  return nullptr;
}

std::unique_ptr<Event> Event::CreateAutoResetEvent(bool initial_state) {
  return nullptr;
}

// TODO(dougvj)
class MacSemaphore : public MacConditionHandle<Semaphore> {
 public:
  MacSemaphore(int initial_count, int maximum_count) { assert_always(); }
  ~MacSemaphore() override = default;
  bool Release(int release_count, int* out_previous_count) override {
    assert_always();
    return false;
  }
};

std::unique_ptr<Semaphore> Semaphore::Create(int initial_count,
                                             int maximum_count) {
  return std::make_unique<MacSemaphore>(initial_count, maximum_count);
}

// TODO(dougvj)
class MacMutant : public MacConditionHandle<Mutant> {
 public:
  MacMutant(bool initial_owner) { assert_always(); }
  ~MacMutant() = default;
  bool Release() override {
    assert_always();
    return false;
  }
};

std::unique_ptr<Mutant> Mutant::Create(bool initial_owner) {
  return std::make_unique<MacMutant>(initial_owner);
}

// TODO(dougvj)
class MacTimer : public MacConditionHandle<Timer> {
 public:
  MacTimer(bool manual_reset) { assert_always(); }
  ~MacTimer() = default;
  bool SetOnce(std::chrono::nanoseconds due_time,
               std::function<void()> opt_callback) override {
    assert_always();
    return false;
  }
  bool SetRepeating(std::chrono::nanoseconds due_time,
                    std::chrono::milliseconds period,
                    std::function<void()> opt_callback) override {
    assert_always();
    return false;
  }
  bool Cancel() override {
    assert_always();
    return false;
  }
};

std::unique_ptr<Timer> Timer::CreateManualResetTimer() {
  return std::make_unique<MacTimer>(true);
}

std::unique_ptr<Timer> Timer::CreateSynchronizationTimer() {
  return std::make_unique<MacTimer>(false);
}

class MacThread : public MacThreadHandle<Thread> {
 public:
  explicit MacThread(pthread_t handle) : MacThreadHandle(handle) {}
  ~MacThread() = default;

  void set_name(std::string name) override {
    // pthread_setname_np(handle_, name.c_str());
  }

  uint32_t system_id() const override { return 0; }

  // TODO(DrChat)
  uint64_t affinity_mask() override { return 0; }
  void set_affinity_mask(uint64_t mask) override { assert_always(); }

  int priority() override {
    int policy;
    struct sched_param param;
    int ret = pthread_getschedparam(handle_, &policy, &param);
    if (ret != 0) {
      return -1;
    }

    return param.sched_priority;
  }

  void set_priority(int new_priority) override {
    struct sched_param param;
    param.sched_priority = new_priority;
    int ret = pthread_setschedparam(handle_, SCHED_FIFO, &param);
  }

  // TODO(DrChat)
  void QueueUserCallback(std::function<void()> callback) override {
    assert_always();
  }

  bool Resume(uint32_t* out_new_suspend_count = nullptr) override {
    assert_always();
    return false;
  }

  bool Suspend(uint32_t* out_previous_suspend_count = nullptr) override {
    assert_always();
    return false;
  }

  void Terminate(int exit_code) override {}
};

thread_local std::unique_ptr<MacThread> current_thread_ = nullptr;

struct ThreadStartData {
  std::function<void()> start_routine;
};
void* ThreadStartRoutine(void* parameter) {
  current_thread_ =
      std::unique_ptr<MacThread>(new MacThread(::pthread_self()));

  auto start_data = reinterpret_cast<ThreadStartData*>(parameter);
  start_data->start_routine();
  delete start_data;
  return 0;
}

std::unique_ptr<Thread> Thread::Create(CreationParameters params,
                                       std::function<void()> start_routine) {
  auto start_data = new ThreadStartData({std::move(start_routine)});

  assert_false(params.create_suspended);
  pthread_t handle;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  int ret = pthread_create(&handle, &attr, ThreadStartRoutine, start_data);
  if (ret != 0) {
    // TODO(benvanik): pass back?
    auto last_error = errno;
    XELOGE("Unable to pthread_create: %d", last_error);
    delete start_data;
    return nullptr;
  }

  return std::unique_ptr<MacThread>(new MacThread(handle));
}

Thread* Thread::GetCurrentThread() {
  if (current_thread_) {
    return current_thread_.get();
  }

  pthread_t handle = pthread_self();

  current_thread_ = std::make_unique<MacThread>(handle);
  return current_thread_.get();
}

void Thread::Exit(int exit_code) {
  pthread_exit(reinterpret_cast<void*>(exit_code));
}

}  // namespace threading
}  // namespace xe
