#ifndef SMTC_MANAGER_H_
#define SMTC_MANAGER_H_

#include <windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

class SmtcManager {
 public:
  static void Initialize(HWND hwnd, flutter::BinaryMessenger* messenger);
  static void Dispose();
};

#endif  // SMTC_MANAGER_H_

