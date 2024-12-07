import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let encryptionChannel = FlutterMethodChannel(name: "enc/dec", binaryMessenger: controller.binaryMessenger)
          encryptionChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
            // Note: this method is invoked on the UI thread.
              if(call.method == "versionName"){
                  guard let args = call.arguments as? [String : Any] else {return}
                  let data = args["data"] as! String
                  let key = args["key"] as! String
                  let encryptedString = CryptoHelper.encrypt(dataFromFlutter: data, keyFromFlutter: key)
                  self?.encrypt(result: result, encrypted: encryptedString!)
                  return
              }else if(call.method == "versionCode"){
                  guard let args = call.arguments as? [String : Any] else {return}
                  let data = args["data"] as! String
                  let key = args["key"] as! String
                  let decryptedString = CryptoHelper.decrypt(dataFromFlutter: data, keyFromFlutter: key)
                  
                  if decryptedString != nil {
                      self?.decrypt(result: result, decrypted: decryptedString!)
                      return
                      
                  } else{
                      result(FlutterMethodNotImplemented)
                      return
                  }
                 
              }else if(call.method == "sdk"){
                  result(self?.getAppVersionName())
                  return
              }
              else{
                  result(FlutterMethodNotImplemented)
                  return
              }
          })

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
