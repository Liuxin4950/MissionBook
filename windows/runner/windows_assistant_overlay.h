#ifndef RUNNER_WINDOWS_ASSISTANT_OVERLAY_H_
#define RUNNER_WINDOWS_ASSISTANT_OVERLAY_H_

#include <flutter/binary_messenger.h>
#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <windows.h>

#include <memory>

// The desktop window owns presentation and OS input only. Assistant requests
// are forwarded to the primary engine and its single workspace.
class WindowsAssistantOverlay {
 public:
  WindowsAssistantOverlay(HWND main_window, flutter::BinaryMessenger* messenger,
                          const flutter::DartProject& project);
  ~WindowsAssistantOverlay();

  bool enabled() const;
  bool SetEnabled(bool enabled);
  void SetAppearance(const char* field, const flutter::EncodableValue& value);

 private:
  class Host;
  std::unique_ptr<Host> host_;
};

#endif  // RUNNER_WINDOWS_ASSISTANT_OVERLAY_H_
