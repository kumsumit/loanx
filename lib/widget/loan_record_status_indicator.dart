import 'package:flutter/material.dart';
import 'package:loanx/model/loan.dart';

/// Shows the delivery state of a loan record independently from its financial
/// lifecycle:
///
/// * one grey tick: saved on this device
/// * two grey ticks: acknowledged by the server
/// * two green ticks: server acknowledged and borrower phone OTP confirmed
/// * teal task icon: the loan is paid/completed
class LoanRecordStatusIndicator extends StatelessWidget {
  const LoanRecordStatusIndicator({
    super.key,
    required this.loan,
    this.onColoredSurface = false,
  });

  final Loan loan;
  final bool onColoredSurface;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brightness = ThemeData.estimateBrightnessForColor(colors.surface);
    final confirmedColor = brightness == Brightness.dark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
    final paidColor = brightness == Brightness.dark
        ? const Color(0xFF80CBC4)
        : const Color(0xFF00796B);

    if (loan.isFinished()) {
      return Tooltip(
        message: 'Paid loan',
        child: Semantics(
          label: 'Paid loan',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: paidColor.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.task_alt_rounded, size: 16, color: paidColor),
                const SizedBox(width: 4),
                Text(
                  'Paid',
                  style: TextStyle(
                    color: paidColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final confirmed = loan.isServerSaved && loan.isClientConfirmed;
    final color = confirmed
        ? confirmedColor
        : onColoredSurface
        ? colors.onPrimary
        : colors.onSurfaceVariant;
    final message = confirmed
        ? 'Borrower confirmed by phone OTP'
        : loan.isServerSaved
        ? 'Saved to server'
        : 'Saved on this device';
    return Tooltip(
      message: message,
      child: Semantics(
        label: message,
        child: Icon(
          loan.isServerSaved ? Icons.done_all_rounded : Icons.done_rounded,
          size: 18,
          color: color,
        ),
      ),
    );
  }
}
