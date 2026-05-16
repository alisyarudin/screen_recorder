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

  // Flag untuk bypass cek password setelah verifikasi berhasil
  private var _quitAuthorized = false

  // Semua jalur quit (NSApp.terminate) diintersep di sini — wajib password jika sudah di-set
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if _quitAuthorized { return .terminateNow }
    guard AdminHelper.hasPassword() else { return .terminateNow }
    DispatchQueue.main.async { self.showQuitPasswordDialog() }
    return .terminateCancel
  }

  // ── Password dialogs ──────────────────────────────────────────────────────

  private func showQuitPasswordDialog() {
    guard let window = NSApp.windows.first else { return }

    // Tampilkan window agar sheet melekat dengan benar dan layar aktif
    let wasHidden = !window.isVisible
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.messageText = "Keluar dari Screen Recorder?"
    alert.informativeText = "Masukkan password admin untuk menutup aplikasi."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Keluar")
    alert.addButton(withTitle: "Batal")

    let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
    field.placeholderString = "Password admin"
    alert.accessoryView = field

    alert.beginSheetModal(for: window) { [weak self] response in
      guard let self else { return }
      if response == .alertFirstButtonReturn {
        if AdminHelper.verifyPassword(field.stringValue) {
          self._quitAuthorized = true
          NSApp.terminate(nil)
        } else {
          // Password salah — defer agar sheet pertama selesai dismiss dulu
          DispatchQueue.main.async { self.showQuitPasswordDialog() }
        }
      } else {
        // User batal — sembunyikan window kembali jika sebelumnya tersembunyi
        if wasHidden { window.orderOut(nil) }
      }
    }
  }
}
