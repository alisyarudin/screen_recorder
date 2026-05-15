import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  // App tetap hidup saat window di-hide
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Klik icon Dock (jika LSUIElement tidak aktif) → tampilkan window
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      NSApp.windows.first?.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
    return true
  }

  // Semua jalur quit (NSApp.terminate) diintersep di sini — wajib password jika sudah di-set
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard AdminHelper.hasPassword() else { return .terminateNow }
    DispatchQueue.main.async { self.showQuitPasswordDialog() }
    return .terminateCancel
  }

  // ── Password dialogs ──────────────────────────────────────────────────────

  private func showQuitPasswordDialog() {
    let alert = NSAlert()
    alert.messageText = "Keluar dari Screen Recorder?"
    alert.informativeText = "Masukkan password admin untuk menutup aplikasi."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Keluar")
    alert.addButton(withTitle: "Batal")

    let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
    field.placeholderString = "Password admin"
    alert.accessoryView = field

    if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
      alert.beginSheetModal(for: window) { [weak self] response in
        guard response == .alertFirstButtonReturn else { return }
        if AdminHelper.verifyPassword(field.stringValue) {
          NSApp.terminate(nil)
        } else {
          self?.showWrongPasswordAlert()
        }
      }
    } else {
      NSApp.activate(ignoringOtherApps: true)
      let response = alert.runModal()
      if response == .alertFirstButtonReturn,
         AdminHelper.verifyPassword(field.stringValue) {
        NSApp.terminate(nil)
      } else if response == .alertFirstButtonReturn {
        showWrongPasswordAlert()
      }
    }
  }

  private func showWrongPasswordAlert() {
    let alert = NSAlert()
    alert.messageText = "Password Salah"
    alert.informativeText = "Password admin tidak sesuai. Aplikasi tetap berjalan."
    alert.alertStyle = .critical
    alert.addButton(withTitle: "OK")
    if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
      alert.beginSheetModal(for: window) { _ in }
    } else {
      alert.runModal()
    }
  }
}
