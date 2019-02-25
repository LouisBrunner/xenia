/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2014 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#include "xenia/base/platform_mac.h"
#include "xenia/ui/window_mac.h"

#pragma mark -
#pragma mark XeniaView

@implementation XeniaView

-(BOOL) wantsLayer { return YES; }

-(BOOL) wantsUpdateLayer { return YES; }

+(Class) layerClass { return [CAMetalLayer class]; }

-(CALayer*) makeBackingLayer {
  CALayer* layer = [self.class.layerClass layer];
  CGSize viewScale = [self convertSizeToBacking: CGSizeMake(1.0, 1.0)];
  layer.contentsScale = MIN(viewScale.width, viewScale.height);
  return layer;
}

-(BOOL) acceptsFirstResponder { return YES; }

@end

@interface XeniaWindow : NSWindow
@end

@implementation XeniaWindow
-(BOOL)canBecomeKeyWindow {
  return YES;
}
-(BOOL)canBecomeMainWindow {
  return YES;
}
@end

@interface XeniaWindowDelegate : NSObject <NSWindowDelegate>
@end

@implementation XeniaWindowDelegate
// TODO: add events
@end


namespace xe {
namespace ui {

std::unique_ptr<Window> Window::Create(Loop* loop, const std::wstring& title) {
  return std::make_unique<MacWindow>(loop, title);
}

MacWindow::MacWindow(Loop* loop, const std::wstring& title)
  : Window(loop, title) {}

MacWindow::~MacWindow() {
  OnDestroy();
  if (window_) {
    [window_ release];
    window_ = nullptr;
  }
  if (view_) {
    [view_ release];
    view_ = nullptr;
  }
}

void MacWindow::EnableMainMenu() {
  if (main_menu_) {
    main_menu_->EnableMenuItem(*this);
  }
}

void MacWindow::DisableMainMenu() {
  if (main_menu_) {
    main_menu_->DisableMenuItem(*this);
  }
}

bool MacWindow::set_title(const std::wstring& title) {
  if (!super::set_title(title)) {
    return false;
  }

  auto newTitle = [[[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(title_.c_str()) length:title_.size()] autorelease];
  [window_ setTitle:newTitle];

  return true;
}

bool MacWindow::SetIcon(const void* buffer, size_t size) {
  auto data = [[NSData dataWithBytes:buffer length:size] autorelease];
  auto image = [[[NSImage alloc] initWithData:data] autorelease];
  if (image) {
    [[NSApplication sharedApplication] setApplicationIconImage:image];
  }
  return image != nullptr;
}

bool MacWindow::is_fullscreen() const { return fullscreen_; }

void MacWindow::ToggleFullscreen(bool fullscreen) {
  if (fullscreen == is_fullscreen()) {
    return;
  }

  fullscreen_ = fullscreen;

  [window_ toggleFullScreen:nil];
}

bool MacWindow::is_bordered() const {
  auto style = [window_ styleMask];
  return (style & NSWindowStyleMaskBorderless) == NSWindowStyleMaskBorderless;
}
void MacWindow::set_bordered(bool enabled) {
  if (is_fullscreen()) {
    return;
  }

  NSUInteger style = NSWindowStyleMaskFullSizeContentView;
  if (enabled) {
    style |= NSWindowStyleMaskBorderless;
  } else {
    style |= NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
  }
  [window_ setStyleMask:style];
}

int MacWindow::get_dpi() const {
  return [window_ backingScaleFactor];
}

void MacWindow::set_cursor_visible(bool value) {
  if (is_cursor_visible_ == value) {
    return;
  }
  super::set_cursor_visible(value);

  if (value) {
    [NSCursor unhide];
  } else {
    [NSCursor hide];
  }
}

void MacWindow::set_focus(bool value) {
  if (has_focus_ == value) {
    return;
  }

  has_focus_ = value;
  if (window_) {
    [window_ makeKeyAndOrderFront: nil];
  }
}

void MacWindow::Resize(int32_t width, int32_t height) {
  auto frame = [window_ frame];
  [window_ setFrame: NSMakeRect(frame.origin.x, frame.origin.y, width, height) display: YES animate: YES];
}
void MacWindow::Resize(int32_t left, int32_t top, int32_t right, int32_t bottom) {
  [window_ setFrame: NSMakeRect(left, top, left - right, top - bottom) display: YES animate: YES];
}

bool MacWindow::Initialize() {
  return OnCreate();
}

void MacWindow::Invalidate() {
  super::Invalidate();
}

void MacWindow::Close() {
  if (closing_) {
    return;
  }
  closing_ = true;
  OnClose();
}

bool MacWindow::OnCreate() {
  auto w = 1280, h = 720;
  auto size = [[NSScreen mainScreen] visibleFrame].size;
  auto x = size.width / 2 - w / 2;
  auto y = size.height / 2 - h / 2;

  view_ = [[XeniaView new] autorelease];
  window_ = [[[XeniaWindow alloc]
    initWithContentRect: NSMakeRect(x, y, w, h)
    styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView
    backing: NSBackingStoreBuffered
    defer: NO
  ] autorelease];
  [window_ setContentView:view_];
  [window_ setDelegate:[[XeniaWindowDelegate new] autorelease]];
  // [windiw_ setReleasedWhenClosed:YES];
  [window_ makeMainWindow];
  [window_ makeKeyWindow];

  auto title = [[[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(title_.c_str()) length:title_.size()] autorelease];
  [window_ setTitle:title];
  return true;
}

void MacWindow::OnMainMenuChange() {
  auto real_menu = static_cast<MacMenuItem*>(main_menu_.get());
  [[NSApplication sharedApplication] setMainMenu:(NSMenu*)real_menu->handle()];
}

void MacWindow::OnDestroy() {
  super::OnDestroy();
}

void MacWindow::OnClose() {
  if (!closing_ && window_) {
    closing_ = true;
  }
  super::OnClose();
}

void MacWindow::OnResize(UIEvent* e) {
  auto frame = [window_ frame];
  int32_t width = frame.size.width;
  int32_t height = frame.size.height;
  if (width != width_ || height != height_) {
    width_ = width;
    height_ = height;
    Layout();
  }
  super::OnResize(e);
}


std::unique_ptr<ui::MenuItem> MenuItem::Create(Type type,
                                               const std::wstring& text,
                                               const std::wstring& hotkey,
                                               std::function<void()> callback) {
  return std::make_unique<MacMenuItem>(type, text, hotkey, callback);
}

MacMenuItem::MacMenuItem(Type type, const std::wstring& text,
                         const std::wstring& hotkey,
                         std::function<void()> callback)
    : MenuItem(type, text, hotkey, std::move(callback)) {
  auto nsText = [[[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(text.c_str()) length:text.size()] autorelease];
  auto nsKey = [[[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(hotkey.c_str()) length:hotkey.size()] autorelease];
  id onClick = ^() { callback_(); };
  switch (type) {
    case MenuItem::Type::kNormal:
    default:
      menu_ = [[NSMenu alloc] initWithTitle:@"Xenia"];
      break;
    case MenuItem::Type::kPopup:
      menu_ = [[NSMenuItem alloc] initWithTitle:nsText action:@selector(onClick) keyEquivalent:[NSString string]];
      break;
    case MenuItem::Type::kSeparator:
      menu_ = [NSMenuItem separatorItem];
      break;
    case MenuItem::Type::kString:
      menu_ = [[NSMenuItem alloc] initWithTitle:nsText action:@selector(onClick) keyEquivalent:nsKey];
      break;
  }
  [menu_ autorelease];
}

MacMenuItem::~MacMenuItem() {
  if (menu_) {
    [menu_ release];
    menu_ = nullptr;
  }
}

void MacMenuItem::EnableMenuItem(Window& window) {
  // TODO: use validateUserInterfaceItem
}

void MacMenuItem::DisableMenuItem(Window& window) {
  // TODO: use validateUserInterfaceItem
}

void MacMenuItem::OnChildAdded(MenuItem* generic_child_item) {
  auto child_item = static_cast<MacMenuItem*>(generic_child_item);
  auto as_menu = reinterpret_cast<NSMenu*>(menu_);
  auto as_item = reinterpret_cast<NSMenuItem*>(menu_);
  auto child_as_menu = reinterpret_cast<NSMenu*>(child_item->handle());
  auto child_as_item = reinterpret_cast<NSMenuItem*>(child_item->handle());
  switch (child_item->type()) {
    case MenuItem::Type::kNormal:
      // Nothing special.
      break;
    case MenuItem::Type::kPopup:
      if (as_item != nullptr) {
        assert(![as_item hasSubmenu]);
        [as_item setSubmenu:child_as_menu];
      } else if (as_menu != nullptr) {
        [as_menu addItem:child_as_item];
      }
      break;
    case MenuItem::Type::kSeparator:
    case MenuItem::Type::kString:
      assert(as_item != nullptr);
      // Get sub menu and if it doesn't exist create it
      auto submenu = [as_item submenu];
      if (submenu == nullptr) {
        submenu = [[[NSMenu alloc] initWithTitle:@"???"] autorelease];
        [as_item setSubmenu:submenu];
      }
      [submenu addItem:child_as_item];
      break;
  }
}

void MacMenuItem::OnChildRemoved(MenuItem* generic_child_item) {
  auto child_item = static_cast<MacMenuItem*>(generic_child_item);
  auto as_menu = reinterpret_cast<NSMenu*>(menu_);
  auto as_item = reinterpret_cast<NSMenuItem*>(menu_);
  auto child_as_menu = reinterpret_cast<NSMenu*>(child_item->handle());
  auto child_as_item = reinterpret_cast<NSMenuItem*>(child_item->handle());
  switch (child_item->type()) {
    case MenuItem::Type::kNormal:
      // Nothing special.
      break;
    case MenuItem::Type::kPopup:
      if (as_item != nullptr) {
        [as_item setSubmenu:nil];
      } else if (as_menu != nullptr) {
        [as_menu removeItem:child_as_item];
      }
      break;
    case MenuItem::Type::kSeparator:
    case MenuItem::Type::kString:
      assert(as_item != nullptr);
      auto submenu = [as_item submenu];
      assert(submenu != nullptr);
      [submenu removeItem:child_as_item];
      break;
  }
}

}  // namespace ui
}  // namespace xe
