#ifndef RUNNER_WINDOWS_SCREEN_CAPTURE_H_
#define RUNNER_WINDOWS_SCREEN_CAPTURE_H_

#include <windows.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

struct WindowsScreenCaptureResult {
  std::vector<std::uint8_t> jpeg;
  const char* error = nullptr;
};

// Owns the frozen frame and the native mouse selection window for one request.
class WindowsScreenCapture {
 public:
  using Completion = std::function<void(WindowsScreenCaptureResult)>;

  WindowsScreenCapture();
  ~WindowsScreenCapture();
  void Start(HMONITOR monitor, HWND previous_window, Completion completion);
  void Cancel();

 private:
  class Selection;
  std::unique_ptr<Selection> selection_;
};

#endif  // RUNNER_WINDOWS_SCREEN_CAPTURE_H_
