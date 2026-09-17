import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/features/auth/otp_verification_screen.dart';
import 'package:loanx/features/auth/phone_login_screen.dart';
import 'package:loanx/service/auth_client.dart';
import 'package:loanx/service/rust_bridge.dart';
import 'package:loanx/provider/provider.dart';

/// Connects an existing offline lender workspace to a verified
/// cloud authentication account.
///
/// Flow:
/// 1. User enters their phone number.
/// 2. LoanX requests an OTP from the authentication service.
/// 3. User verifies the OTP.
/// 4. The verified phone number is persisted locally.
/// 5. The screen returns `true` to the caller.
///
/// The AuthClient is intentionally owned by this screen rather than relying
/// on a global `activeAuthClient`, which keeps this flow self-contained.
class ConnectAccountScreen extends ConsumerStatefulWidget {
  const ConnectAccountScreen({this.switchToBorrower = false, super.key});

  /// When true, this flow changes the active app experience after OTP
  /// verification. It never relinks or replaces the existing local owner.
  final bool switchToBorrower;

  @override
  ConsumerState<ConnectAccountScreen> createState() =>
      _ConnectAccountScreenState();
}

class _ConnectAccountScreenState extends ConsumerState<ConnectAccountScreen> {
  late final AuthClient _authClient;

  PhoneNumber? _pendingPhone;

  bool _initializing = true;
  bool _requestingOtp = false;
  bool _verifyingOtp = false;

  @override
  void initState() {
    super.initState();

    _authClient = AuthClient();

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize the Flutter Rust Bridge before using AuthClient.
      await RustBridge.ensureInitialized();

      if (!mounted) return;

      setState(() {
        _initializing = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
      });
    }
  }

  /// Requests an OTP for the supplied phone number.
  ///
  /// Returning null means success.
  /// Returning a String means the UI should display that error.
  Future<String?> _request(PhoneNumber phone) async {
    if (_requestingOtp) {
      return null;
    }

    setState(() {
      _requestingOtp = true;
    });

    try {
      await RustBridge.ensureInitialized();

      await _authClient.requestOtp(phone);

      if (!mounted) return null;

      setState(() {
        _pendingPhone = phone;
      });

      return null;
    } catch (error, stackTrace) {
      debugPrint('LoanX Connect Account OTP request failed: $error');
      debugPrint('$stackTrace');
      return 'Could not send verification code'.tr();
    } finally {
      if (mounted) {
        setState(() {
          _requestingOtp = false;
        });
      }
    }
  }

  /// Verifies the OTP entered by the user.
  ///
  /// Returning null means verification succeeded.
  /// Returning a String means verification failed.
  Future<String?> _verify(String code) async {
    if (_verifyingOtp) {
      return null;
    }

    final phone = _pendingPhone;

    if (phone == null) {
      return 'Verification unavailable'.tr();
    }

    if (code.trim().isEmpty) {
      return 'Please enter the verification code'.tr();
    }

    setState(() {
      _verifyingOtp = true;
    });
    final preferredLanguage = context.locale.languageCode;

    try {
      await RustBridge.ensureInitialized();

      final verified = await _authClient.verifyOtp(
        phone,
        code.trim(),
        preferredLanguage,
      );

      if (!verified) {
        return 'Invalid verification code'.tr();
      }

      ref.invalidate(loanListProvider);

      final e164Phone = CountryCatalog.e164(phone.isoCode, phone.nsn);

      // Persist the verified account information only after successful
      // server-side verification.
      AppSettings.putPhoneAuthVerified(true);

      if (widget.switchToBorrower) {
        // This is an experience preference, not an authorization role. The
        // server session established above is the source of authorization.
        AppSettings.putOnboardingInterest(1);
      }

      AppSettings.putVerifiedPhoneNumber(e164Phone);

      AppSettings.putVerifiedPhoneCountryCode(phone.isoCode);

      await AppSettings.flush();

      if (!mounted) return null;

      Navigator.of(context).pop(true);

      return null;
    } catch (_) {
      return 'Account could not be linked to this workspace'.tr();
    } finally {
      if (mounted) {
        setState(() {
          _verifyingOtp = false;
        });
      }
    }
  }

  void _changeNumber() {
    if (!mounted) return;

    setState(() {
      _pendingPhone = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: Text('Connect account'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Connect account'.tr())),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pendingPhone == null
            ? PhoneLoginScreen(
                key: const ValueKey('phone_login'),
                onContinue: _request,
              )
            : OtpVerificationScreen(
                key: const ValueKey('otp_verification'),
                phoneNumber: _pendingPhone!,
                onVerify: _verify,
                onResend: () => _request(_pendingPhone!),
                onChangeNumber: _changeNumber,
              ),
      ),
    );
  }

  @override
  void dispose() {
    // AuthClient is owned by this State and therefore should not be disposed
    // here unless AuthClient itself exposes a dispose/close method.
    super.dispose();
  }
}
