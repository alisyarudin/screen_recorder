#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>
#include <shellapi.h>

#include "native_channels.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Native MethodChannel host (activity monitor + admin).
  std::unique_ptr<NativeChannels> native_channels_;

  // Tray icon (system notification area) — mirrors the macOS status item so the
  // app can be hidden to the tray instead of fully closing.
  void SetupTrayIcon();
  void TeardownTrayIcon();
  void ShowTrayMenu();
  void ShowMainWindow();
  void HideMainWindow();

  static constexpr UINT kTrayCallbackMessage = WM_APP + 1;
  static constexpr UINT kMenuIdOpen = 1001;
  static constexpr UINT kMenuIdQuit = 1002;

  NOTIFYICONDATAW tray_icon_data_{};
  HMENU tray_menu_ = nullptr;
  bool tray_installed_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
