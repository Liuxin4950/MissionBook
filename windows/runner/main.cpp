#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <algorithm>
#include <filesystem>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  constexpr wchar_t kSingleInstanceName[] =
      L"Local\\MissionBook.SingleInstance";
  HANDLE single_instance = CreateMutexW(nullptr, FALSE, kSingleInstanceName);
  if (!single_instance) return EXIT_FAILURE;
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    const HWND existing = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Mission Book");
    if (existing) {
      PostMessageW(existing, kMissionBookActivateMessage, 0, 0);
    }
    CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // The installer lets users choose a folder. Flutter assets must therefore
  // resolve beside the executable, not against Explorer's working directory.
  std::vector<wchar_t> executable_path(32768, L'\0');
  const DWORD path_length = GetModuleFileNameW(
      nullptr, executable_path.data(), static_cast<DWORD>(executable_path.size()));
  if (path_length == 0 ||
      path_length >= static_cast<DWORD>(executable_path.size())) {
    CloseHandle(single_instance);
    return EXIT_FAILURE;
  }
  const std::filesystem::path install_directory =
      std::filesystem::path(std::wstring(executable_path.data(), path_length))
          .parent_path();
  if (!SetCurrentDirectoryW(install_directory.c_str())) {
    CloseHandle(single_instance);
    return EXIT_FAILURE;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project((install_directory / L"data").wstring());

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  const auto monitor = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO bounds{sizeof(bounds)};
  if (GetMonitorInfoW(monitor, &bounds)) {
    const auto monitor_dpi = FlutterDesktopGetDpiForMonitor(monitor);
    const int dpi = monitor_dpi ? static_cast<int>(monitor_dpi) : 96;
    const int width = bounds.rcWork.right - bounds.rcWork.left;
    const int height = bounds.rcWork.bottom - bounds.rcWork.top;
    size.width = std::clamp(MulDiv(width, 96, dpi) - 30, 350, 1280);
    size.height = std::clamp(MulDiv(height, 96, dpi) - 30, 340, 720);
  }
  if (!window.Create(L"Mission Book", origin, size)) {
    CloseHandle(single_instance);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  if (!window.Show()) {
    CloseHandle(single_instance);
    return EXIT_FAILURE;
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  CloseHandle(single_instance);
  return EXIT_SUCCESS;
}
