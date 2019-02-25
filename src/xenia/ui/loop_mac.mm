/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2016 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#include "xenia/ui/loop_mac.h"

// TODO: remove
#include <iostream>

@interface XeniaAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation XeniaAppDelegate
@end


namespace xe {
namespace ui {

std::unique_ptr<Loop> Loop::Create() { return std::make_unique<MacLoop>(); }

MacLoop::MacLoop() : thread_id_() {
  pool_ = [NSAutoreleasePool new];
  app_ = [NSApplication sharedApplication];
  [app_ setDelegate:[[XeniaAppDelegate new] autorelease]];

  xe::threading::Fence init_fence;
  thread_ = std::thread([&init_fence, this]() {
    xe::threading::set_name("Mac Loop");

    thread_id_ = std::this_thread::get_id();
    init_fence.Signal();

    ThreadMain();

    quit_fence_.Signal();
  });
  init_fence.Wait();
}

MacLoop::~MacLoop() {
  Quit();
  thread_.join();
  [pool_ release];
}

void MacLoop::ThreadMain() {
  [app_ run];

  UIEvent e(nullptr);
  on_quit(&e);
}

bool MacLoop::is_on_loop_thread() {
  return thread_id_ == std::this_thread::get_id();
}

void MacLoop::Post(std::function<void()> fn) {
  std::cout << "POST!" << std::endl;
  // TODO: do it
}

void MacLoop::PostDelayed(std::function<void()> fn, uint64_t delay_millis) {
  std::cout << "POST! (delayed)" << std::endl;
  // TODO: do it
}

void MacLoop::Quit() {
  [app_ terminate:nil];
}

void MacLoop::AwaitQuit() { quit_fence_.Wait(); }

}  // namespace ui
}  // namespace xe
