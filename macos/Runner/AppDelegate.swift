import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

   private func getAppVersionName() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "N/A"
    }

    private func getAppVersionCode() -> Int {
        if let version = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
           let versionCode = Int(version) {
            return versionCode
        }
        return -1
    }
}
