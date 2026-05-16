import Cocoa
import FlutterMacOS
import ScreenCaptureKit

class MainFlutterWindow: NSWindow {
  private var closeDelegate: WindowCloseDelegate?
  private var statusItem: NSStatusItem?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 640, height: 480)

    let cd = WindowCloseDelegate()
    closeDelegate = cd
    self.delegate = cd

    setupMenuBarIcon()

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
        if CGPreflightScreenCaptureAccess() {
          result(true)
        } else {
          CGRequestScreenCaptureAccess()
          result(false)
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
          let frameRate     = args["frameRate"]     as? String ?? "30"
          let maxResolution = args["maxResolution"] as? String ?? "original"
          let useHevc       = args["useHevc"]       as? Bool   ?? false
          ScreenRecorder.shared.start(
            outputPath: outputPath,
            quality: quality,
            frameRate: frameRate,
            maxResolution: maxResolution,
            useHevc: useHevc
          ) { success, error in
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

    // ── Activity Monitor MethodChannel ───────────────────────────────────────
    let monitorChannel = FlutterMethodChannel(
      name: "com.jasnita/activity_monitor",
      binaryMessenger: messenger
    )

    ActivityMonitor.shared.onAppChanged = { appName in
      monitorChannel.invokeMethod("onAppChanged", arguments: appName)
    }

    monitorChannel.setMethodCallHandler { call, result in
      switch call.method {

      case "startActivityMonitoring":
        ActivityMonitor.shared.startMonitoring()
        result(nil)

      case "stopActivityMonitoring":
        ActivityMonitor.shared.stopMonitoring()
        result(nil)

      case "getIdleSeconds":
        result(ActivityMonitor.shared.getIdleSeconds())

      case "takeScreenshot":
        guard let args = call.arguments as? [String: Any],
              let path  = args["outputPath"] as? String
        else {
          result(false)
          return
        }
        result(ActivityMonitor.shared.takeScreenshot(outputPath: path))

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // ── Admin MethodChannel ───────────────────────────────────────────────────
    let adminChannel = FlutterMethodChannel(
      name: "com.jasnita/admin",
      binaryMessenger: messenger
    )

    adminChannel.setMethodCallHandler { call, result in
      switch call.method {

      case "setAdminPassword":
        if let password = call.arguments as? String {
          AdminHelper.setPassword(password)
          result(true)
        } else { result(false) }

      case "changeAdminPassword":
        guard let args = call.arguments as? [String: String],
              let old = args["old"], let new = args["new"]
        else { result(false); return }
        result(AdminHelper.changePassword(old: old, new: new))

      case "clearAdminPassword":
        AdminHelper.clearPassword()
        result(true)

      case "hasAdminPassword":
        result(AdminHelper.hasPassword())

      case "verifyAdminPassword":
        if let password = call.arguments as? String {
          result(AdminHelper.verifyPassword(password))
        } else { result(false) }

      case "installAutoStart":
        result(AdminHelper.installAutoStart())

      case "uninstallAutoStart":
        result(AdminHelper.uninstallAutoStart())

      case "getAutoStartStatus":
        result(AdminHelper.getAutoStartStatus())

      case "quitApp":
        NSApp.terminate(nil)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }

  // MARK: - Menu bar icon (tray)

  private func setupMenuBarIcon() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem?.button {
      if #available(macOS 11.0, *) {
        let img = NSImage(systemSymbolName: "record.circle.fill",
                          accessibilityDescription: "Screen Recorder")
        img?.isTemplate = true
        button.image = img
      } else {
        // Fallback macOS 10.15
        let img = NSImage(size: NSSize(width: 16, height: 16))
        img.lockFocus()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 12, height: 12)).fill()
        img.unlockFocus()
        button.image = img
      }
      button.toolTip = "Screen Recorder"
    }

    let menu = NSMenu()
    let openItem = NSMenuItem(title: "Buka Screen Recorder",
                              action: #selector(showSelf),
                              keyEquivalent: "")
    openItem.target = self
    menu.addItem(openItem)
    menu.addItem(.separator())

    let quitItem = NSMenuItem(title: "Keluar…",
                              action: #selector(requestQuit),
                              keyEquivalent: "")
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem?.menu = menu
  }

  @objc private func showSelf() {
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func requestQuit() {
    NSApp.terminate(nil)
  }
}

// MARK: - Close protection (requires admin password)

class WindowCloseDelegate: NSObject, NSWindowDelegate {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    // Sembunyikan window — monitoring tetap berjalan di background.
    // App masih aktif di Dock; klik icon Dock untuk tampilkan kembali.
    sender.orderOut(nil)
    return false
  }


}
