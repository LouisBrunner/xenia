/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2016 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#include "xenia/ui/file_picker.h"

#include <string>
#include "xenia/base/platform_mac.h"

namespace xe {
namespace ui {

class MacFilePicker : public FilePicker {
 public:
  MacFilePicker();
  ~MacFilePicker() override;

  bool Show(void* parent_window_handle) override;

 private:
};

std::unique_ptr<FilePicker> FilePicker::Create() {
  return std::make_unique<MacFilePicker>();
}

MacFilePicker::MacFilePicker() = default;

MacFilePicker::~MacFilePicker() = default;

bool MacFilePicker::Show(void* parent_window_handle) {
  NSSavePanel* panel;
  NSOpenPanel* opanel;
  if (mode() == Mode::kOpen) {
    opanel = [[NSOpenPanel openPanel] autorelease];
    [opanel setCanChooseFiles: type() == Type::kFile];
    [opanel setCanChooseDirectories: type() == Type::kDirectory];
    [opanel setAllowsMultipleSelection: multi_selection()];
    panel = opanel;
  } else {
    panel = [[NSSavePanel savePanel] autorelease];
    [panel setCanCreateDirectories: YES];
  }

  bool allowAll = false;
  auto exts = [[NSMutableArray arrayWithCapacity:extensions().size()] autorelease];
  for (auto& extension : extensions()) {
    auto ext = [[[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(extension.second.c_str()) length:extension.second.size()] autorelease];
    auto parts = [ext componentsSeparatedByString:@";"];
    for (int i = 0; i < [parts count]; ++i) {
      auto part = [parts objectAtIndex:i];
      auto extParts = [part componentsSeparatedByString:@"."];
      if ([extParts count] == 2) {
        auto extension = [extParts objectAtIndex:1];
        if ([extension isEqualToString:@"*"]) {
          allowAll = true;
          break;
        }
        [exts addObject: extension];
      }
    }
    if (allowAll) {
      break;
    }
  }
  [panel setAllowsOtherFileTypes: allowAll];
  if (!allowAll) {
    [panel setAllowedFileTypes: exts];
  }

  auto newTitle = [[[NSString alloc] initWithCharacters:reinterpret_cast<const unichar *>(title().c_str()) length:title().size()] autorelease];
  [panel setTitle:newTitle];

  auto response = [panel runModal];
  if (response == NSModalResponseOK) {
    std::vector<std::wstring> selected_files;
    if (mode() == Mode::kOpen) {
      for (int i = 0; i < [opanel.URLs count]; ++i) {
        auto selection = opanel.URLs[i].absoluteString;
        std::wstring selected(selection.length, '\0');
        [selection getCharacters:reinterpret_cast<unichar *>(&selected.front()) range:NSMakeRange(0, selection.length)];
        selected_files.push_back(selected);
      }
    } else {
      auto selection = panel.URL.absoluteString;
      std::wstring selected(selection.length, '\0');
      [selection getCharacters:reinterpret_cast<unichar *>(&selected.front()) range:NSMakeRange(0, selection.length)];
      selected_files.push_back(selected);
    }
    set_selected_files(selected_files);
  }
  return response == NSModalResponseOK;
}

}  // namespace ui
}  // namespace xe
