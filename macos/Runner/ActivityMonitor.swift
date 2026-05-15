import Cocoa
import IOKit

class ActivityMonitor: NSObject {

    static let shared = ActivityMonitor()
    private override init() { super.init() }

    var onAppChanged: ((String) -> Void)?
    private var isMonitoring = false

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        print("[Activity] Monitoring started")

        // Langsung lapor app yang sedang aktif
        if let app = NSWorkspace.shared.frontmostApplication {
            let name = app.localizedName ?? "Unknown"
            DispatchQueue.main.async { [weak self] in
                self?.onAppChanged?(name)
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        print("[Activity] Monitoring stopped")
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication else { return }
        let name = app.localizedName ?? "Unknown"
        print("[Activity] App changed → \(name)")
        DispatchQueue.main.async { [weak self] in
            self?.onAppChanged?(name)
        }
    }

    // MARK: - Idle time (via IOKit HIDIdleTime)

    func getIdleSeconds() -> Double {
        let service = IOServiceGetMatchingService(0, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }

        var propertiesRef: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(
            service, &propertiesRef, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS,
              let props = propertiesRef?.takeRetainedValue() as? [String: Any],
              let idleNS = props["HIDIdleTime"] as? Int64
        else { return 0 }

        return Double(idleNS) / 1_000_000_000
    }

    // MARK: - Screenshot (CGDisplay → JPEG)

    func takeScreenshot(outputPath: String) -> Bool {
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            print("[Activity] Screenshot: CGDisplayCreateImage failed")
            return false
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.75]
        ) else {
            print("[Activity] Screenshot: JPEG encoding failed")
            return false
        }

        let url = URL(fileURLWithPath: outputPath)
        do {
            try data.write(to: url)
            print("[Activity] Screenshot saved → \(outputPath)")
            return true
        } catch {
            print("[Activity] Screenshot write error: \(error)")
            return false
        }
    }
}
