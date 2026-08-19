import 'package:intl/intl.dart';
import 'package:loanx/model/loan.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Creates printable loan receipts and delegates printer selection to the
/// platform print service. On Android this includes USB and Bluetooth printers
/// exposed by an installed print service (for example the manufacturer's app).
class LoanPrintingService {
  LoanPrintingService._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static Future<void> printLoan(Loan loan) async {
    final bytes = await _buildReceipt(loan).save();

    await Printing.layoutPdf(
      name: 'LoanX receipt${loan.id == null ? '' : ' #${loan.id}'}',
      onLayout: (_) async => bytes,
    );
  }

  /// Opens the platform share sheet with the loan receipt as a PDF file.
  static Future<void> shareLoanPdf(Loan loan) async {
    final bytes = await _buildReceipt(loan).save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'loanx-receipt${loan.id == null ? '' : '-${loan.id}'}.pdf',
    );
  }

  static pw.Document _buildReceipt(Loan loan) {
    final interest = loan.calculateInterest();
    final earlyRedemptionCharge = loan.calculateEarlyRedemptionCharge();
    final total = loan.calculateCollectable();
    final isCompleted = loan.isFinished();
    final rows = <List<String>>[
      ['Loan ID', loan.id?.toString() ?? '—'],
      ['Customer', loan.depositorName],
      ['Phone', loan.phoneNumber],
      if (loan.relativeName.isNotEmpty) ['Relative', loan.relativeName],
      if (loan.address.isNotEmpty) ['Address', loan.address],
      ['Created', loan.dateCreatedFormat],
      ['Principal', _currency.format(loan.loanAmount)],
      if (loan.weight > 0) ...[
        ['Mortgage weight', '${loan.weight.toStringAsFixed(2)} g'],
        [
          'Loan value per gram',
          _currency.format(loan.loanAmount / loan.weight),
        ],
      ],
      ['Interest rate', '${loan.interestRate.toStringAsFixed(2)}%'],
      ['Interest type', _interestType(loan.interestType)],
      ['Interest frequency', _interestFrequency(loan.interestFrequency)],
      ['Mortgage term', '${loan.mortgageTermYears} years'],
      if (loan.lockInDays > 0) ...[
        ['Lock-in period', '${loan.lockInDays} days'],
        ['Lock-in ends', DateFormat('dd MMM yyyy').format(loan.lockInEndsAt)],
        [
          'Early redemption charge',
          _currency.format(loan.earlyRedemptionCharge),
        ],
      ],
      ['Accrued interest', _currency.format(interest)],
      if (earlyRedemptionCharge > 0)
        [
          'Applied early redemption charge',
          _currency.format(earlyRedemptionCharge),
        ],
      ['Total due', _currency.format(total)],
      ['Status', isCompleted ? 'Completed' : 'Active'],
      if (isCompleted) ['Completed on', loan.dateFinishedFormat],
      if (loan.settlementAmount != null)
        ['Settlement amount', _currency.format(loan.settlementAmount)],
      if (loan.completedBy.isNotEmpty) ['Received by', loan.completedBy],
      if (loan.completionReference.isNotEmpty)
        ['Reference', loan.completionReference],
      if (loan.additionalDetails.isNotEmpty) ['Notes', loan.additionalDetails],
    ];

    return pw.Document()..addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'LoanX receipt',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              cellAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headers: const ['Detail', 'Value'],
              data: rows,
              border: pw.TableBorder.all(color: PdfColors.grey400),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'Thank you',
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _interestType(int value) =>
      value == InterestType.compound.index ? 'Compound' : 'Simple';

  static String _interestFrequency(int value) {
    switch (InterestFrequency.values[value]) {
      case InterestFrequency.monthly:
        return 'Monthly';
      case InterestFrequency.quarterly:
        return 'Quarterly';
      case InterestFrequency.halfYearly:
        return 'Half-yearly';
      case InterestFrequency.yearly:
        return 'Yearly';
    }
  }
}
