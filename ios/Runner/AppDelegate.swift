import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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