#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

// |text| in UTF-16, for the window's title.
std::wstring Utf16FromUtf8(const std::string& text) {
  if (text.empty()) {
    return std::wstring();
  }
  int length = ::MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                     static_cast<int>(text.size()), nullptr, 0);
  std::wstring wide(length, L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                        wide.data(), length);
  return wide;
}

// The number under |key| in |args|, or 0.
double NumberArgument(const flutter::EncodableMap& args, const char* key) {
  auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return 0;
  }
  if (const auto* value = std::get_if<double>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return *value;
  }
  return 0;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "gubasic/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        // Closing as the user would, once the handler has returned: the
        // program has ended (D81).
        if (call.method_name() == "close") {
          ::PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (call.method_name() != "fit" || args == nullptr) {
          result->NotImplemented();
          return;
        }
        std::string title;
        auto it = args->find(flutter::EncodableValue("title"));
        if (it != args->end()) {
          if (const auto* text = std::get_if<std::string>(&it->second)) {
            title = *text;
          }
        }
        FitClientArea(Utf16FromUtf8(title), NumberArgument(*args, "width"),
                      NumberArgument(*args, "height"));
        result->Success();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::FitClientArea(const std::wstring& title, double width,
                                  double height) {
  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }
  if (!title.empty()) {
    ::SetWindowText(window, title.c_str());
  }
  if (width <= 0 || height <= 0) {
    return;
  }
  UINT dpi = FlutterDesktopGetDpiForHWND(window);
  double scale = dpi / 96.0;
  RECT frame = {0, 0, static_cast<LONG>(width * scale + 0.5),
                static_cast<LONG>(height * scale + 0.5)};
  DWORD style = static_cast<DWORD>(::GetWindowLongPtr(window, GWL_STYLE));
  DWORD ex_style = static_cast<DWORD>(::GetWindowLongPtr(window, GWL_EXSTYLE));
  // The frame for this display's scale where Windows can tell it (Windows
  // 10, version 1607 and later), as the runner's own window does.
  using AdjustForDpi = BOOL(WINAPI*)(LPRECT, DWORD, BOOL, DWORD, UINT);
  HMODULE user32 = ::GetModuleHandle(L"user32.dll");
  auto adjust_for_dpi =
      user32 == nullptr ? nullptr
                        : reinterpret_cast<AdjustForDpi>(
                              ::GetProcAddress(user32, "AdjustWindowRectExForDpi"));
  if (adjust_for_dpi != nullptr) {
    adjust_for_dpi(&frame, style, FALSE, ex_style, dpi);
  } else {
    ::AdjustWindowRectEx(&frame, style, FALSE, ex_style);
  }
  MONITORINFO monitor = {sizeof(monitor)};
  ::GetMonitorInfo(::MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                   &monitor);
  const RECT& work = monitor.rcWork;
  LONG outer_width = (std::min)(frame.right - frame.left, work.right - work.left);
  LONG outer_height =
      (std::min)(frame.bottom - frame.top, work.bottom - work.top);
  ::SetWindowPos(window, nullptr,
                 work.left + (work.right - work.left - outer_width) / 2,
                 work.top + (work.bottom - work.top - outer_height) / 2,
                 outer_width, outer_height, SWP_NOZORDER | SWP_NOACTIVATE);
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
