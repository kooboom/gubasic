#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

// Keeps the window inside the display's work area: the template's
// 1280 x 720 at the display's scale is larger than a 1920 x 1080 display
// at 150 %, where the window was cut off at the right and bottom; a
// window made smaller for it is centred (D108).
void FitToWorkArea(HWND window) {
  MONITORINFO monitor = {sizeof(monitor)};
  ::GetMonitorInfo(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                   &monitor);
  const RECT& work = monitor.rcWork;
  RECT rect;
  ::GetWindowRect(window, &rect);
  LONG width = (std::min)(rect.right - rect.left, work.right - work.left);
  LONG height = (std::min)(rect.bottom - rect.top, work.bottom - work.top);
  ::SetWindowPos(window, nullptr,
                 work.left + (work.right - work.left - width) / 2,
                 work.top + (work.bottom - work.top - height) / 2, width,
                 height, SWP_NOZORDER | SWP_NOACTIVATE);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"GuBASIC Player", origin, size)) {
    return EXIT_FAILURE;
  }
  FitToWorkArea(window.GetHandle());
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
