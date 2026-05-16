#ifndef RUNNER_NATIVE_CHANNELS_H_
#define RUNNER_NATIVE_CHANNELS_H_

#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <windows.h>

// Native counterpart to the macOS MainFlutterWindow setup: registers the
// `com.jasnita/screen_recording` (permission stubs), `com.jasnita/activity_monitor`
// and `com.jasnita/admin` MethodChannels on the Windows side so the Dart layer
// can use the same APIs on both platforms.
class NativeChannels {
 public:
  explicit NativeChannels(flutter::FlutterEngine* engine);
  ~NativeChannels();

  NativeChannels(const NativeChannels&) = delete;
  NativeChannels& operator=(const NativeChannels&) = delete;

  // Sends an `onQuitRequested` event to Dart so the UI can show the password
  // dialog before allowing termination. Called by the tray icon's "Keluar" menu.
  void RequestQuit();

 private:
  void RegisterActivityMonitorChannel();
  void RegisterAdminChannel();

  // Foreground-app hook callback (WinEvent).
  static void CALLBACK OnForegroundChanged(HWINEVENTHOOK hook, DWORD event,
                                            HWND hwnd, LONG idObject,
                                            LONG idChild, DWORD eventThread,
                                            DWORD eventTime);

  void StartMonitoring();
  void StopMonitoring();
  void ReportApp(HWND hwnd);

  flutter::FlutterEngine* engine_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> monitor_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> admin_channel_;

  HWINEVENTHOOK foreground_hook_ = nullptr;
  bool is_monitoring_ = false;
  std::wstring last_reported_app_;

  // Singleton-style back-pointer so the static WinEvent callback can route
  // events back to the live instance.
  static NativeChannels* instance_;
};

#endif  // RUNNER_NATIVE_CHANNELS_H_
