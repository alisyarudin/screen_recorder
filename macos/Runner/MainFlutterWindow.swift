import Cocoa
import FlutterMacOS
import ScreenCaptureKit

class MainFlutterWindow: NSWindow {
  private var closeDelegate: WindowCloseDelegate?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 640, height: 480)

    let cd = WindowCloseDelegate()
    closeDelegate = cd
    self.delegate = cd

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger

    // ── Screen Recording MethodChannel ────────────────────────────────────────
    let screenChannel = FlutterMethodChannel(
      name: "com.jasnita/screen_recording",
      binaryMessenger: messenger
    )

    if #available(macOS 12.3, *) {
      ScreenRecorder.shared.onUnexpectedStop = { errorMsg in
        screenChannel.invokeMethod("onRecordingError", arguments: errorMsg)
      }
    }

    screenChannel.setMethodCallHandler { call, result in
      switch call.method {

      case "requestPermission":
        if #available(macOS 12.3, *) {
          SCShareableContent.getExcludingDesktopWindows(
            false, onScreenWindowsOnly: false
          ) { _, error in
            DispatchQueue.main.async { result(error == nil) }
          }
        } else {
          result(CGRequestScreenCaptureAccess())
        }

      case "openSystemSettings":
        let urlStr = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        if let url = URL(string: urlStr) { NSWorkspace.shared.open(url) }
        result(nil)

      case "startNativeRecording":
        if #available(macOS 12.3, *) {
          guard let args       = call.arguments as? [String: Any],
                let outputPath = args["outputPath"] as? String,
                let quality    = args["quality"]    as? String
          else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "outputPath/quality wajib diisi",
                                details: nil))
            return
          }
          ScreenRecorder.shared.start(outputPath: outputPath, quality: quality) { success, error in
            result(["success": success, "error": error])
          }
        } else {
          result(["success": false, "error": "ScreenCaptureKit membutuhkan macOS 12.3+"])
        }

      case "stopNativeRecording":
        if #available(macOS 12.3, *) {
          ScreenRecorder.shared.stop { savedPath in result(savedPath) }
        } else {
          result(nil)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

// MARK: - Close confirmation

class WindowCloseDelegate: NSObject, NSWindowDelegate {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Tutup Screen Recorder?"
    alert.informativeText = "Yakin ingin menutup aplikasi?"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Tutup")
    alert.addButton(withTitle: "Batal")

    alert.beginSheetModal(for: sender) { response in
      if response == .alertFirstButtonReturn {
        NSApp.terminate(nil)
      }
    }
    return false
  }
}
