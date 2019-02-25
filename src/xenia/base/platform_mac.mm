/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2015 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#include "xenia/base/platform_mac.h"
#include <string>

namespace xe {

void LaunchBrowser(const char* url) {
  NSString *urlStr = [NSString stringWithCString:url encoding:NSUTF8StringEncoding];
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: urlStr]];
}

}  // namespace xe
