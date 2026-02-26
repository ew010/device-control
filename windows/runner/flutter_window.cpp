#include "flutter_window.h"

#include <windows.h>

#include <chrono>
#include <cstdint>
#include <optional>
#include <string>
#include <thread>

#include "flutter/generated_plugin_registrant.h"

namespace {
double ReadDoubleArg(const flutter::EncodableMap* args,
                     const char* key,
                     double fallback = 0.0) {
  if (args == nullptr) {
    return fallback;
  }
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) {
    return fallback;
  }
  if (const auto* v = std::get_if<double>(&it->second)) {
    return *v;
  }
  if (const auto* v = std::get_if<int32_t>(&it->second)) {
    return static_cast<double>(*v);
  }
  if (const auto* v = std::get_if<int64_t>(&it->second)) {
    return static_cast<double>(*v);
  }
  return fallback;
}

std::string ReadStringArg(const flutter::EncodableMap* args, const char* key) {
  if (args == nullptr) {
    return "";
  }
  auto it = args->find(flutter::EncodableValue(key));
  if (it == args->end()) {
    return "";
  }
  if (const auto* v = std::get_if<std::string>(&it->second)) {
    return *v;
  }
  return "";
}

LONG ToAbsoluteX(double x_norm) {
  const double clamped = x_norm < 0.0 ? 0.0 : (x_norm > 1.0 ? 1.0 : x_norm);
  return static_cast<LONG>(clamped * 65535.0);
}

LONG ToAbsoluteY(double y_norm) {
  const double clamped = y_norm < 0.0 ? 0.0 : (y_norm > 1.0 ? 1.0 : y_norm);
  return static_cast<LONG>(clamped * 65535.0);
}

void SendMouseMoveAbs(double x_norm, double y_norm) {
  INPUT input = {};
  input.type = INPUT_MOUSE;
  input.mi.dx = ToAbsoluteX(x_norm);
  input.mi.dy = ToAbsoluteY(y_norm);
  input.mi.dwFlags = MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_MOVE;
  SendInput(1, &input, sizeof(INPUT));
}

void SendMouseFlag(DWORD flag) {
  INPUT input = {};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = flag;
  SendInput(1, &input, sizeof(INPUT));
}

void SendUnicodeText(const std::wstring& text) {
  for (wchar_t ch : text) {
    INPUT down = {};
    down.type = INPUT_KEYBOARD;
    down.ki.wScan = ch;
    down.ki.dwFlags = KEYEVENTF_UNICODE;

    INPUT up = down;
    up.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

    INPUT events[2] = {down, up};
    SendInput(2, events, sizeof(INPUT));
  }
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
  RegisterNativeInputChannel();
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

void FlutterWindow::OnDestroy() {
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

void FlutterWindow::RegisterNativeInputChannel() {
  native_input_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "phonecontrol/native_input",
          &flutter::StandardMethodCodec::GetInstance());

  native_input_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        const std::string message = HandleNativeInputCall(call.method_name(), args);
        result->Success(flutter::EncodableValue(message));
      });
}

std::string FlutterWindow::HandleNativeInputCall(const std::string& method,
                                                 const flutter::EncodableMap* args) {
  if (method == "status") {
    return "windows: native input ready";
  }
  if (method == "openAccessibilitySettings") {
    return "not required on windows";
  }

  if (method == "injectTap") {
    const double x = ReadDoubleArg(args, "x");
    const double y = ReadDoubleArg(args, "y");
    SendMouseMoveAbs(x, y);
    SendMouseFlag(MOUSEEVENTF_LEFTDOWN);
    SendMouseFlag(MOUSEEVENTF_LEFTUP);
    return "injectTap ok";
  }

  if (method == "injectDrag") {
    const double from_x = ReadDoubleArg(args, "fromX");
    const double from_y = ReadDoubleArg(args, "fromY");
    const double to_x = ReadDoubleArg(args, "toX");
    const double to_y = ReadDoubleArg(args, "toY");

    SendMouseMoveAbs(from_x, from_y);
    SendMouseFlag(MOUSEEVENTF_LEFTDOWN);
    for (int i = 1; i <= 12; i++) {
      const double t = static_cast<double>(i) / 12.0;
      const double x = from_x + (to_x - from_x) * t;
      const double y = from_y + (to_y - from_y) * t;
      SendMouseMoveAbs(x, y);
      std::this_thread::sleep_for(std::chrono::milliseconds(12));
    }
    SendMouseFlag(MOUSEEVENTF_LEFTUP);
    return "injectDrag ok";
  }

  if (method == "injectText") {
    const std::string utf8 = ReadStringArg(args, "text");
    if (utf8.empty()) {
      return "injectText ok";
    }
    const int wide_len = MultiByteToWideChar(
        CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
    if (wide_len <= 1) {
      return "injectText failed: invalid utf8";
    }
    std::wstring wide(static_cast<size_t>(wide_len), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &wide[0], wide_len);
    if (!wide.empty() && wide.back() == L'\0') {
      wide.pop_back();
    }
    SendUnicodeText(wide);
    return "injectText ok";
  }

  return "unsupported method: " + method;
}
