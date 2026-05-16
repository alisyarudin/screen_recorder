#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

#pragma comment(lib, "shell32.lib")

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
  native_channels_ = std::make_unique<NativeChannels>(
      flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupTrayIcon();

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
  TeardownTrayIcon();
  native_channels_.reset();
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

    case WM_CLOSE:
      // Mirror the macOS behaviour: closing the window only hides it; the app
      // keeps running in the tray. The user must use the tray "Keluar" menu to
      // actually quit (which triggers the admin-password dialog if set).
      HideMainWindow();
      return 0;

    case kTrayCallbackMessage:
      switch (LOWORD(lparam)) {
        case WM_LBUTTONDBLCLK:
          ShowMainWindow();
          return 0;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          return 0;
      }
      return 0;

    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kMenuIdOpen:
          ShowMainWindow();
          return 0;
        case kMenuIdQuit:
          // Bring window to front so any password dialog Dart shows is visible,
          // then ask Dart to run the admin-password flow.
          ShowMainWindow();
          if (native_channels_) native_channels_->RequestQuit();
          return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

// ────────────────────────────────────────────────────────────────────────────
// Tray icon
// ────────────────────────────────────────────────────────────────────────────

void FlutterWindow::SetupTrayIcon() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  HICON icon = static_cast<HICON>(LoadImageW(
      GetModuleHandle(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
      GetSystemMetrics(SM_CXSMICON), GetSystemMetrics(SM_CYSMICON),
      LR_DEFAULTCOLOR));
  if (!icon) {
    icon = LoadIcon(nullptr, IDI_APPLICATION);
  }

  ZeroMemory(&tray_icon_data_, sizeof(tray_icon_data_));
  tray_icon_data_.cbSize = sizeof(tray_icon_data_);
  tray_icon_data_.hWnd = hwnd;
  tray_icon_data_.uID = 1;
  tray_icon_data_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  tray_icon_data_.uCallbackMessage = kTrayCallbackMessage;
  tray_icon_data_.hIcon = icon;
  wcscpy_s(tray_icon_data_.szTip, L"Screen Recorder");

  tray_installed_ = Shell_NotifyIconW(NIM_ADD, &tray_icon_data_) == TRUE;

  tray_menu_ = CreatePopupMenu();
  if (tray_menu_) {
    AppendMenuW(tray_menu_, MF_STRING, kMenuIdOpen, L"Buka Screen Recorder");
    AppendMenuW(tray_menu_, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(tray_menu_, MF_STRING, kMenuIdQuit, L"Keluar…");
  }
}

void FlutterWindow::TeardownTrayIcon() {
  if (tray_installed_) {
    Shell_NotifyIconW(NIM_DELETE, &tray_icon_data_);
    tray_installed_ = false;
  }
  if (tray_menu_) {
    DestroyMenu(tray_menu_);
    tray_menu_ = nullptr;
  }
}

void FlutterWindow::ShowTrayMenu() {
  if (!tray_menu_) return;
  HWND hwnd = GetHandle();
  if (!hwnd) return;

  POINT pt;
  GetCursorPos(&pt);
  // Required so the menu disappears when the user clicks outside it.
  SetForegroundWindow(hwnd);
  TrackPopupMenu(tray_menu_, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN,
                 pt.x, pt.y, 0, hwnd, nullptr);
  PostMessage(hwnd, WM_NULL, 0, 0);
}

void FlutterWindow::ShowMainWindow() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  ShowWindow(hwnd, SW_SHOW);
  if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
  SetForegroundWindow(hwnd);
}

void FlutterWindow::HideMainWindow() {
  HWND hwnd = GetHandle();
  if (!hwnd) return;
  ShowWindow(hwnd, SW_HIDE);
}
