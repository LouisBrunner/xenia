/**
 ******************************************************************************
 * Xenia : Xbox 360 Emulator Research Project                                 *
 ******************************************************************************
 * Copyright 2015 Ben Vanik. All rights reserved.                             *
 * Released under the BSD license - see LICENSE in the root for more details. *
 ******************************************************************************
 */

#ifndef XENIA_BASE_PLATFORM_MAC_H_
#define XENIA_BASE_PLATFORM_MAC_H_

// NOTE: if you're including this file it means you are explicitly depending
// on macOS headers. Including this file outside of macOS platform specific
// source code will break portability
#include "xenia/base/platform.h"

#import <AppKit/AppKit.h>
#import <QuartzCore/CAMetalLayer.h>

#endif  // XENIA_BASE_PLATFORM_MAC_H_
