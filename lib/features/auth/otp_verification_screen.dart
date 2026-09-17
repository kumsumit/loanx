import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/domain/country_catalog.dart';
import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/service/device_performance.dart';
import 'package:pinput/pinput.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    required this.phoneNumber,
    required this.onVerify,
    required this.onResend,
    required this.onChangeNumber,
    this.initialCode,
    super.key,
  });

  final PhoneNumber phoneNumber;
  final Future<String?> Function(String code) onVerify;
  final Future<String?> Function() onResend;
  final VoidCallback onChangeNumber;
  final String? initialCode;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _controller = TextEditingController();
  final _otpFocusNode = FocusNode();
  int _resendSeconds = 30;
  Timer? _timer;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode case final code?) {
      _controller.text = code;
    }
    _otpFocusNode.addListener(_scrollOtpFieldIntoView);
    _startTimer();
  }

  void _scrollOtpFieldIntoView() {
    if (!_otpFocusNode.hasFocus) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fieldContext = _otpFocusNode.context;
      if (!mounted || fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.25,
      );
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verify(String code) async {
    if (code.length != 6 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onVerify(code);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _submitting) return;
    final error = await widget.onResend();
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpFocusNode
      ..removeListener(_scrollOtpFieldIntoView)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final basicEffects = DevicePerformance.isSafe;
    final phone = CountryCatalog.e164(
      widget.phoneNumber.isoCode,
      widget.phoneNumber.nsn,
    );
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: basicEffects ? colors.surface : null,
          gradient: basicEffects
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surface,
                    colors.primaryContainer.withValues(alpha: .32),
                  ],
                ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 460,
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: IconButton.filledTonal(
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).backButtonTooltip,
                            onPressed: widget.onChangeNumber,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Align(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: basicEffects ? colors.primary : null,
                              gradient: basicEffects
                                  ? null
                                  : LinearGradient(
                                      colors: [colors.primary, colors.tertiary],
                                    ),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: basicEffects
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: colors.primary.withValues(
                                          alpha: .22,
                                        ),
                                        blurRadius: 28,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                            ),
                            child: Icon(
                              Icons.sms_outlined,
                              size: 40,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          LocaleKeys.verifyYourNumber.tr(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          LocaleKeys.otpSentTo.tr(namedArgs: {'phone': phone}),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 34),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Pinput inserts five 8px separators for a six-digit
                            // code. Size each box from the available width so the
                            // row remains visible on compact Android screens.
                            const separatorWidth = 8.0;
                            const pinCount = 6;
                            final pinWidth =
                                ((constraints.maxWidth -
                                            (pinCount - 1) * separatorWidth) /
                                        pinCount)
                                    .clamp(0.0, 50.0);
                            final pinTheme = PinTheme(
                              width: pinWidth,
                              height: 58,
                              textStyle: theme.textTheme.titleLarge,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: colors.outlineVariant,
                                ),
                              ),
                            );

                            return Semantics(
                              label: LocaleKeys.sixDigitVerificationCode.tr(),
                              child: Pinput(
                                key: const Key('otp-input'),
                                length: pinCount,
                                controller: _controller,
                                focusNode: _otpFocusNode,
                                autofocus: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                defaultPinTheme: pinTheme,
                                // Pinput has platform-specific defaults for
                                // submitted cells. Keep every state on the same
                                // responsive dimensions; otherwise entered cells
                                // can grow wider than the available row.
                                submittedPinTheme: pinTheme,
                                followingPinTheme: pinTheme,
                                disabledPinTheme: pinTheme,
                                focusedPinTheme: pinTheme.copyWith(
                                  decoration: pinTheme.decoration?.copyWith(
                                    border: Border.all(
                                      color: colors.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                errorPinTheme: pinTheme.copyWith(
                                  decoration: pinTheme.decoration?.copyWith(
                                    border: Border.all(color: colors.error),
                                  ),
                                ),
                                onChanged: (_) => setState(() => _error = null),
                                onCompleted: _verify,
                              ),
                            );
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            key: const Key('otp-error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('verify-otp'),
                          onPressed:
                              _controller.text.length == 6 && !_submitting
                              ? () => _verify(_controller.text)
                              : null,
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(LocaleKeys.verifyAndContinue.tr()),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          key: const Key('resend-otp'),
                          onPressed: _resendSeconds == 0 ? _resend : null,
                          child: Text(
                            _resendSeconds == 0
                                ? LocaleKeys.resendCode.tr()
                                : LocaleKeys.resendCodeIn.tr(
                                    namedArgs: {'seconds': '$_resendSeconds'},
                                  ),
                          ),
                        ),
                        TextButton(
                          onPressed: widget.onChangeNumber,
                          child: Text(LocaleKeys.changePhoneNumber.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
