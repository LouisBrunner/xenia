/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2016 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#ifndef XENIA_UI_LOOP_MAC_H_
#define XENIA_UI_LOOP_MAC_H_

#include <list>
#include <mutex>
#include <thread>

#include "xenia/base/platform_mac.h"
#include "xenia/base/threading.h"
#include "xenia/ui/loop.h"

namespace xe {
namespace ui {

class MacLoop : public Loop {
 public:
  MacLoop();
  ~MacLoop() override;

  bool is_on_loop_thread() override;

  void Post(std::function<void()> fn) override;
  void PostDelayed(std::function<void()> fn, uint64_t delay_millis) override;

  void Quit() override;
  void AwaitQuit() override;

 private:
  void ThreadMain();

  NSAutoreleasePool* pool_;
  NSApplication* app_;
  std::thread::id thread_id_;
  std::thread thread_;
  xe::threading::Fence quit_fence_;
};

}  // namespace ui
}  // namespace xe

#endif  // XENIA_UI_LOOP_MAC_H_
