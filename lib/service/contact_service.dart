import 'package:flutter/services.dart';

class ContactService {
  const ContactService._();

  static const _channel = MethodChannel('loanx');

  /// Opens the device contact editor with [name] and [phoneNumber] prefilled.
  /// The user confirms the save in the system contacts app.
  static Future<bool> createContact({
    required String name,
    required String phoneNumber,
  }) async {
    if (name.trim().isEmpty || phoneNumber.trim().isEmpty) return false;

    try {
      return await _channel.invokeMethod<bool>('createContact', {
            'name': name.trim(),
            'phoneNumber': phoneNumber.trim(),
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
