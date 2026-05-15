import Foundation
import CryptoKit

class AdminHelper {

    private static let passwordKey = "com.jasnita.adminPasswordHash"

    // MARK: - Password (stored in UserDefaults, hashed SHA-256)

    static func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func setPassword(_ password: String) {
        let hash = hashPassword(password)
        UserDefaults.standard.set(hash, forKey: passwordKey)
        print("[Admin] Password hash stored")
    }

    static func clearPassword() {
        UserDefaults.standard.removeObject(forKey: passwordKey)
        print("[Admin] Password cleared")
    }

    static func hasPassword() -> Bool {
        let hash = UserDefaults.standard.string(forKey: passwordKey) ?? ""
        return !hash.isEmpty
    }

    static func verifyPassword(_ input: String) -> Bool {
        guard let stored = UserDefaults.standard.string(forKey: passwordKey),
              !stored.isEmpty else { return false }
        return hashPassword(input) == stored
    }

    /// Verifies old password then sets new one. Returns true on success.
    static func changePassword(old: String, new: String) -> Bool {
        if hasPassword() && !verifyPassword(old) { return false }
        setPassword(new)
        return true
    }

    // MARK: - Auto-start via LaunchAgent (KeepAlive = restart if killed)

    private static var launchAgentLabel: String { "com.jasnita.screenrecorder" }
    private static var launchAgentPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(launchAgentLabel).plist"
    }

    static func installAutoStart() -> Bool {
        guard let execPath = Bundle.main.executablePath else {
            print("[Admin] installAutoStart: no executablePath")
            return false
        }

        let dir = NSHomeDirectory() + "/Library/LaunchAgents"
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [execPath],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ThrottleInterval": 5,
        ]

        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0)
        else { return false }

        do {
            try data.write(to: URL(fileURLWithPath: launchAgentPath))
        } catch {
            print("[Admin] Write LaunchAgent failed: \(error)")
            return false
        }

        _launchctl(["load", launchAgentPath])
        print("[Admin] LaunchAgent installed → \(launchAgentPath)")
        return true
    }

    static func uninstallAutoStart() -> Bool {
        _launchctl(["unload", launchAgentPath])
        try? FileManager.default.removeItem(atPath: launchAgentPath)
        print("[Admin] LaunchAgent removed")
        return true
    }

    static func getAutoStartStatus() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentPath)
    }

    @discardableResult
    private static func _launchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }
}
