import Flutter
import UIKit
import Contacts
import ContactsUI

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
    let contactChannel = FlutterMethodChannel(name: "loanx", binaryMessenger: controller.binaryMessenger)
    contactChannel.setMethodCallHandler { [weak self] call, result in
      if call.method == "versionName" {
        result(self?.getAppVersionName() ?? "Unavailable")
        return
      }
      if call.method == "versionCode" {
        result(self?.getAppVersionCode() ?? -1)
        return
      }
      guard call.method == "createContact" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let name = arguments["name"] as? String,
            let phoneNumber = arguments["phoneNumber"] as? String,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterError(code: "INVALID_CONTACT", message: "A name and phone number are required.", details: nil))
        return
      }
      self?.showNewContact(name: name, phoneNumber: phoneNumber)
      result(true)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func showNewContact(name: String, phoneNumber: String) {
    let contact = CNMutableContact()
    let nameParts = name.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 1)
    contact.givenName = nameParts.first.map(String.init) ?? ""
    contact.familyName = nameParts.count > 1 ? String(nameParts[1]) : ""
    contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phoneNumber))]
    let editor = CNContactViewController(forNewContact: contact)
    editor.delegate = self
    let navigationController = UINavigationController(rootViewController: editor)
    window?.rootViewController?.present(navigationController, animated: true)
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

extension AppDelegate: CNContactViewControllerDelegate {
  func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
    viewController.dismiss(animated: true)
  }
}
