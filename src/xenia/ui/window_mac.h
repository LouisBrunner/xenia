/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2016 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#ifndef XENIA_UI_WINDOW_MAC_H_
#define XENIA_UI_WINDOW_MAC_H_

#include <string>

#include "xenia/base/platform_mac.h"
#include "xenia/ui/menu_item.h"
#include "xenia/ui/window.h"

#pragma mark -
#pragma mark XeniaView

@interface XeniaView : NSView
@end

namespace xe {
namespace ui {

class MacWindow : public Window {
  using super = Window;

 public:
  MacWindow(Loop* loop, const std::wstring& title);
  ~MacWindow() override;

  NativePlatformHandle native_platform_handle() const override { return nullptr; }
  NativeWindowHandle native_handle() const override { return view_; }

  void EnableMainMenu() override;
  void DisableMainMenu() override;

  bool set_title(const std::wstring& title) override;

  bool SetIcon(const void* buffer, size_t size) override;

  bool is_fullscreen() const override;
  void ToggleFullscreen(bool fullscreen) override;

  bool is_bordered() const override;
  void set_bordered(bool enabled) override;

  int get_dpi() const override;

  void set_cursor_visible(bool value) override;
  void set_focus(bool value) override;

  void Resize(int32_t width, int32_t height) override;
  void Resize(int32_t left, int32_t top, int32_t right,
              int32_t bottom) override;

  bool Initialize() override;
  void Invalidate() override;
  void Close() override;

 protected:
  bool OnCreate() override;
  void OnMainMenuChange() override;
  void OnDestroy() override;
  void OnClose() override;

  void OnResize(UIEvent* e) override;

 private:
  NSWindow* window_ = nullptr;
  XeniaView* view_ = nullptr;

  bool closing_ = false;
  bool fullscreen_ = false;
};

class MacMenuItem : public MenuItem {
 public:
  MacMenuItem(Type type, const std::wstring& text, const std::wstring& hotkey,
              std::function<void()> callback);
  ~MacMenuItem() override;

  NSObject* handle() { return menu_; }

  void EnableMenuItem(Window& window) override;
  void DisableMenuItem(Window& window) override;

  using MenuItem::OnSelected;

 protected:
  void OnChildAdded(MenuItem* child_item) override;
  void OnChildRemoved(MenuItem* child_item) override;

 private:
   NSObject* menu_ = nullptr;
};

}  // namespace ui
}  // namespace xe

#endif  // XENIA_UI_WINDOW_MAC_H_
