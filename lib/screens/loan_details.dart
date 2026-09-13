import 'package:loanx/l10n/locale_keys.g.dart';
import 'package:loanx/l10n/codegen_loader.g.dart';
import 'package:loanx/l10n/intl_locale.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/extension/loan_enum_localization.dart';
import 'package:loanx/extension/system_value_localization.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/loan_change.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/screens/add_loan.dart';
import 'package:loanx/service/contact_service.dart';
import 'package:loanx/service/upi_validator.dart';
import 'package:loanx/widget/snackbar.dart';
import 'package:loanx/widget/language_picker.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LoanDetails extends ConsumerWidget {
  const LoanDetails({super.key, required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLoan = ref
        .watch(loanListProvider)
        .maybeWhen(
          data: (loans) => loans.firstWhere(
            (item) => item.id == loan.id,
            orElse: () => loan,
          ),
          orElse: () => loan,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.loanDetails.tr()),
        actions: [
          IconButton(
            tooltip: LocaleKeys.saveBorrowerAsContact.tr(),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: currentLoan.phoneNumber.trim().isEmpty
                ? null
                : () async {
                    final opened = await ContactService.createContact(
                      name: currentLoan.depositorName,
                      phoneNumber: currentLoan.phoneNumber,
                    );
                    if (context.mounted && !opened) {
                      showSnackBar(
                        context,
                        LocaleKeys.couldNotOpenTheContactEditor.tr(),
                      );
                    }
                  },
          ),
          IconButton(
            tooltip: LocaleKeys.shareLoanDetails.tr(),
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final shareLocale = await _chooseShareLanguage(context);
              if (shareLocale == null || !context.mounted) return;

              final relations = ref.read(familyRelationListProvider).value;
              final materials = ref.read(mortgageMaterialListProvider).value;
              final relation = relations?.firstWhere(
                (item) => item.id == currentLoan.familyRelationId,
              );
              final material = materials?.firstWhere(
                (item) => item.id == currentLoan.mortgageMaterialId,
              );
              final box = context.findRenderObject() as RenderBox?;
              SharePlus.instance.share(
                ShareParams(
                  subject: _shareCopy(
                    shareLocale,
                  ).detailsFor(currentLoan.depositorName),
                  text: _shareText(
                    currentLoan,
                    locale: shareLocale,
                    relativeRelation: relation?.name,
                    mortgageName: material?.name,
                  ),
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ),
              );
            },
          ),
          IconButton(
            tooltip: LocaleKeys.editLoan2.tr(),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LoanInput(loan: currentLoan),
                ),
              );
            },
          ),
          IconButton(
            tooltip: currentLoan.isFinished()
                ? LocaleKeys.loanAlreadyCompleted.tr()
                : LocaleKeys.markAsComplete.tr(),
            icon: const Icon(Icons.task_alt_outlined),
            onPressed: currentLoan.isFinished()
                ? null
                : () => _markComplete(context, ref, currentLoan),
          ),
        ],
      ),
      body: ref
          .watch(familyRelationListProvider)
          .when(
            data: (relations) => ref
                .watch(mortgageMaterialListProvider)
                .when(
                  data: (materials) {
                    final relation = relations.firstWhere(
                      (item) => item.id == currentLoan.familyRelationId,
                    );
                    final material = materials.firstWhere(
                      (item) => item.id == currentLoan.mortgageMaterialId,
                    );
                    return _DetailsContent(
                      loan: currentLoan,
                      relation: relation.localizedName,
                      material: material.localizedName,
                    );
                  },
                  error: (_, _) => const _LoadError(),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
            error: (_, _) => const _LoadError(),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
    );
  }

  String _shareText(
    Loan loan, {
    required Locale locale,
    String? relativeRelation,
    String? mortgageName,
  }) {
    final copy = _shareCopy(locale);
    final localeName = intlLocaleName(locale);
    final currency = NumberFormat.currency(
      locale: localeName,
      symbol: '₹',
      decimalDigits: 0,
    );
    final date = DateFormat('d MMM yyyy', localeName);
    final dateTime = DateFormat('d MMM yyyy, h:mm a', localeName);
    final collectable = loan.calculateCollectable();
    final calculationDate = loan.dateFinished ?? DateTime.now();
    final relation = relativeRelation == null
        ? null
        : copy.systemValue(relativeRelation);
    final material = mortgageName == null
        ? copy.notRecorded
        : copy.systemValue(mortgageName);
    final interestType = copy.interestType(
      InterestType.values[loan.interestType],
    );
    final lines = <String>[
      copy.loanDetails,
      '',
      '${copy.borrower}: ${loan.depositorName}',
      '${copy.phone}: ${loan.phoneNumber}',
      '${copy.address}: ${loan.address}',
      '${copy.relativeName}: ${loan.relativeName}${relation == null ? '' : ' ($relation)'}',
      '${copy.mortgageName}: $material',
      '${copy.weight}: ${loan.weight > 0 ? '${loan.weight.toStringAsFixed(2)} ${copy.systemValue(loan.weightUnit)}' : copy.notRecorded}',
      '${copy.loanAmount}: ${currency.format(loan.loanAmount)}',
      '${copy.interest}: ${loan.interestRate}% ($interestType)',
      '${copy.mortgageTerm}: ${copy.yearCount(loan.mortgageTermYears)}',
      if (loan.lockInDays > 0)
        '${copy.lockInPeriod}: ${copy.dayCount(loan.lockInDays)} (${copy.until} ${date.format(loan.lockInEndsAt)})',
      if (loan.lockInDays > 0)
        '${copy.earlyRedemptionCharge}: ${currency.format(loan.earlyRedemptionCharge)} ${copy.beforeThisDate}',
      '${copy.estimatedDue(date.format(calculationDate))}: ${currency.format(collectable)}',
      '${copy.status}: ${loan.isFinished() ? copy.completed : copy.active}',
      '${copy.created}: ${date.format(loan.dateCreated)}',
      if (loan.isFinished()) ...[
        '${copy.completed}: ${dateTime.format(loan.dateFinished!)}',
        '${copy.receivedBy}: ${loan.completedBy.isEmpty ? copy.notRecorded : loan.completedBy}',
        '${copy.amountReceived}: ${loan.settlementAmount == null ? copy.notRecorded : currency.format(loan.settlementAmount)}',
      ],
      if (loan.additionalDetails.trim().isNotEmpty)
        '${copy.additionalDetails}: ${loan.additionalDetails}',
      if (loan.termsAndConditions.trim().isNotEmpty)
        '${copy.termsAndConditions}: ${loan.termsAndConditions}',
      '',
      copy.sentVia,
    ];
    return lines.join('\n');
  }

  Future<Locale?> _chooseShareLanguage(BuildContext context) {
    final copy = _shareCopy(context.locale);
    return showDialog<Locale>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(copy.chooseShareLanguage),
        children: [
          for (final language in appLanguages)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(language.locale),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(language.nativeName),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _markComplete(
    BuildContext context,
    WidgetRef ref,
    Loan loan,
  ) async {
    final receivedByController = TextEditingController();
    final amountController = TextEditingController(
      text: loan.calculateCollectable().toStringAsFixed(2),
    );
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocaleKeys.completeAndReturnItem.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Record the handover details for a complete settlement history.'
                    .tr(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: receivedByController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: LocaleKeys.itemReceivedBy.tr(),
                  hintText: LocaleKeys.nameOfBorrowerOrAuthorisedRecipient.tr(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: LocaleKeys.amountReceived.tr(),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.receiptOrReferenceNumberOptional.tr(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: LocaleKeys.settlementNotesOptional.tr(),
                  hintText: LocaleKeys.itemConditionWitnessesOrOtherDetails
                      .tr(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim());
              if (receivedByController.text.trim().isEmpty ||
                  amount == null ||
                  amount < 0) {
                showSnackBar(
                  context,
                  LocaleKeys.enterTheRecipientAndAValidAmountReceived.tr(),
                );
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(LocaleKeys.completeLoan.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      receivedByController.dispose();
      amountController.dispose();
      referenceController.dispose();
      notesController.dispose();
      return;
    }

    loan.complete(
      receivedBy: receivedByController.text.trim(),
      amountReceived: double.parse(amountController.text.trim()),
      reference: referenceController.text.trim(),
      notes: notesController.text.trim(),
    );
    receivedByController.dispose();
    amountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    await ref.read(loanListProvider.notifier).updateLoan(loan);
    if (context.mounted) {
      showSnackBar(context, LocaleKeys.loanMarkedAsComplete.tr());
    }
  }
}

class _DetailsContent extends ConsumerWidget {
  const _DetailsContent({
    required this.loan,
    required this.relation,
    required this.material,
  });

  final Loan loan;
  final String relation;
  final String material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final interest = loan.calculateInterest();
    final earlyRedemptionCharge = loan.calculateEarlyRedemptionCharge();
    final collectable = loan.calculateCollectable();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.primary, colors.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.depositorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: colors.onPrimary),
                    ),
                  ),
                  _StatusPill(completed: loan.isFinished()),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                LocaleKeys.collectableAmount.tr(),
                style: TextStyle(
                  color: colors.onPrimary.withValues(alpha: .7),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    currency.format(collectable),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AmountMetric(
                      label: 'Principal',
                      value: currency.format(loan.loanAmount),
                    ),
                  ),
                  Expanded(
                    child: _AmountMetric(
                      label: 'Interest',
                      value: currency.format(interest),
                    ),
                  ),
                ],
              ),
              if (!loan.isFinished()) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _showUpiPaymentQr(context, collectable),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(LocaleKeys.showUpiPaymentQr.tr()),
                  ),
                ),
              ],
              if (earlyRedemptionCharge > 0) ...[
                const SizedBox(height: 10),
                _AmountMetric(
                  label: 'Early redemption charge',
                  value: currency.format(earlyRedemptionCharge),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Loan information'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.percent_rounded,
                label: 'Interest',
                value:
                    '${loan.interestRate}% · ${InterestType.values[loan.interestType].localizedLabel}',
              ),
              if (loan.interestType == InterestType.compound.index)
                _DetailRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Frequency',
                  value: InterestFrequency
                      .values[loan.interestFrequency]
                      .localizedLabel,
                ),
              _DetailRow(
                icon: Icons.event_repeat_outlined,
                label: 'Mortgage term',
                value: LocaleKeys.yearsCount.tr(
                  namedArgs: {'count': loan.mortgageTermYears.toString()},
                ),
              ),
              if (loan.lockInDays > 0) ...[
                _DetailRow(
                  icon: Icons.lock_clock_outlined,
                  label: 'Lock-in period',
                  value:
                      '${loan.lockInDays} days · Until ${DateFormat('d MMM yyyy').format(loan.lockInEndsAt)}',
                ),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Early redemption charge',
                  value: currency.format(loan.earlyRedemptionCharge),
                ),
              ],
              _DetailRow(
                icon: Icons.inventory_2_outlined,
                label: 'Mortgage material',
                value: material,
              ),
              if (loan.weight > 0) ...[
                _DetailRow(
                  icon: Icons.scale_outlined,
                  label: 'Mortgage weight',
                  value: '${loan.weight.toStringAsFixed(2)} ${loan.weightUnit}',
                ),
                _DetailRow(
                  icon: Icons.analytics_outlined,
                  label: LocaleKeys.loanValuePerUnit.tr(
                    namedArgs: {'unit': loan.weightUnit},
                  ),
                  value: currency.format(loan.loanAmount / loan.weight),
                ),
              ],
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Created',
                value: DateFormat(
                  'd MMM yyyy, h:mm a',
                ).format(loan.dateCreated),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Borrower information'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: loan.phoneNumber,
              ),
              if (loan.phoneNumber.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _callBorrower(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const _ContactActionLabel(
                            icon: Icons.call_outlined,
                            label: 'Call',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _showMessageOptions(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const _ContactActionLabel(
                            icon: Icons.message_outlined,
                            label: 'Message',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _DetailRow(
                icon: Icons.people_outline_rounded,
                label: relation,
                value: loan.relativeName,
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: loan.address,
              ),
              _DetailRow(
                icon: Icons.notes_rounded,
                label: 'Additional details',
                value: loan.additionalDetails.trim().isEmpty
                    ? LocaleKeys.noAdditionalDetails.tr()
                    : loan.additionalDetails,
                last: loan.termsAndConditions.trim().isEmpty,
              ),
              if (loan.termsAndConditions.trim().isNotEmpty)
                _DetailRow(
                  icon: Icons.gavel_outlined,
                  label: 'Terms and conditions',
                  value: loan.termsAndConditions,
                  last: true,
                ),
            ],
          ),
        ),
        if (loan.isFinished()) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Settlement record'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.event_available_outlined,
                  label: 'Completed',
                  value: DateFormat(
                    'd MMM yyyy, h:mm a',
                  ).format(loan.dateFinished!),
                ),
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Item received by',
                  value: loan.completedBy.isEmpty
                      ? LocaleKeys.notRecordedForThisOlderLoan.tr()
                      : loan.completedBy,
                ),
                _DetailRow(
                  icon: Icons.payments_outlined,
                  label: 'Amount received',
                  value: loan.settlementAmount == null
                      ? LocaleKeys.notRecordedForThisOlderLoan.tr()
                      : currency.format(loan.settlementAmount),
                ),
                if (loan.completionReference.trim().isNotEmpty)
                  _DetailRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Reference number',
                    value: loan.completionReference,
                  ),
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Settlement notes',
                  value: loan.completionNotes.trim().isEmpty
                      ? LocaleKeys.noNotesRecorded.tr()
                      : loan.completionNotes,
                  last: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionTitle('Activity history'),
        const SizedBox(height: 10),
        ref
            .watch(loanChangesProvider(loan.id!))
            .when(
              data: (changes) => changes.isEmpty
                  ? Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          LocaleKeys.noActivityHasBeenRecordedYet.tr(),
                        ),
                      ),
                    )
                  : Card(
                      child: Column(
                        children: [
                          for (var index = 0; index < changes.length; index++)
                            _ChangeRow(
                              change: changes[index],
                              last: index == changes.length - 1,
                            ),
                        ],
                      ),
                    ),
              error: (_, _) => const SizedBox(),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _showUpiPaymentQr(
    BuildContext context,
    double collectable,
  ) async {
    final payment = await showDialog<({String upiId, double amount})>(
      context: context,
      builder: (_) => _UpiPaymentFormDialog(
        initialUpiId: AppSettings.getDefaultUpiId(),
        initialAmount: collectable,
      ),
    );

    if (payment == null || !context.mounted) return;

    final paymentUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': payment.upiId,
        'am': payment.amount.toStringAsFixed(2),
        'cu': 'INR',
        'tn': LocaleKeys.loanRepaymentFor.tr(
          namedArgs: {'name': loan.depositorName},
        ),
      },
    );
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocaleKeys.scanToPayWithUpi.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 240,
                height: 240,
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: PrettyQrView.data(data: paymentUri.toString()),
              ),
              const SizedBox(height: 16),
              Text(
                currency.format(payment.amount),
                style: Theme.of(dialogContext).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              SelectableText(
                payment.upiId,
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                LocaleKeys.verifyUpiRecipient.tr(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(LocaleKeys.done.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _callBorrower(BuildContext context) async {
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: loan.phoneNumber.trim()),
      mode: LaunchMode.externalApplication,
    );
    if (context.mounted && !launched) {
      showSnackBar(context, LocaleKeys.couldNotOpenThePhoneApp.tr());
    }
  }

  void _showMessageOptions(BuildContext context) {
    final message =
        'Hello ${loan.depositorName},\n\n'
        'This is regarding your loan record in LoanX.';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: Text(LocaleKeys.sms.tr()),
              onTap: () => _sendMessage(
                context,
                sheetContext,
                Uri(
                  scheme: 'sms',
                  path: loan.phoneNumber.trim(),
                  queryParameters: {'body': message},
                ),
                'Could not open the messaging app',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: Text(LocaleKeys.whatsapp.tr()),
              onTap: () => _sendMessage(
                context,
                sheetContext,
                Uri.https('wa.me', '/${_whatsAppNumber(loan.phoneNumber)}', {
                  'text': message,
                }),
                'Could not open WhatsApp',
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(
    BuildContext context,
    BuildContext sheetContext,
    Uri uri,
    String errorMessage,
  ) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    if (context.mounted && !launched) {
      showSnackBar(context, errorMessage.tr());
    }
  }

  String _whatsAppNumber(String phoneNumber) =>
      phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
}

class _UpiPaymentFormDialog extends StatefulWidget {
  const _UpiPaymentFormDialog({
    required this.initialUpiId,
    required this.initialAmount,
  });

  final String initialUpiId;
  final double initialAmount;

  @override
  State<_UpiPaymentFormDialog> createState() => _UpiPaymentFormDialogState();
}

class _UpiPaymentFormDialogState extends State<_UpiPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _upiIdController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _upiIdController = TextEditingController(text: widget.initialUpiId);
    _amountController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(LocaleKeys.createUpiPaymentQr.tr()),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _upiIdController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: LocaleKeys.receivingUpiId.tr(),
                hintText: LocaleKeys.upiIdHint.tr(),
                prefixIcon: const Icon(Icons.account_balance_outlined),
              ),
              validator: (value) {
                final upiId = value?.trim() ?? '';
                if (!isValidUpiIdFormat(upiId)) {
                  return LocaleKeys.enterValidUpiId.tr();
                }
                if (!hasSupportedUpiHandle(upiId)) {
                  return LocaleKeys.invalidUpiHandle.tr(
                    namedArgs: {'handle': upiHandle(upiId)},
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: LocaleKeys.amount.tr(),
                prefixText: '₹ ',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || !amount.isFinite || amount <= 0) {
                  return LocaleKeys.enterAmountGreaterThanZero.tr();
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LocaleKeys.cancel.tr()),
        ),
        FilledButton.icon(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.pop(context, (
              upiId: _upiIdController.text.trim(),
              amount: double.parse(_amountController.text.trim()),
            ));
          },
          icon: const Icon(Icons.qr_code_2_rounded),
          label: Text(LocaleKeys.createQr.tr()),
        ),
      ],
    );
  }
}

class _ContactActionLabel extends StatelessWidget {
  const _ContactActionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label.tr(), softWrap: false),
          ),
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.last});

  final LoanChange change;
  final bool last;

  @override
  Widget build(BuildContext context) => _DetailRow(
    icon: Icons.history_rounded,
    label: DateFormat('d MMM yyyy, h:mm a').format(change.createdAt),
    value: change.description,
    last: last,
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.onPrimary.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        completed ? LocaleKeys.completed.tr() : LocaleKeys.active.tr(),
        style: TextStyle(
          color: colors.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color.withValues(alpha: .7), fontSize: 12),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.tr(), style: Theme.of(context).textTheme.titleMedium);
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.trExists() ? label.tr() : label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(value, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(indent: 58),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(LocaleKeys.unableToLoadLoanDetails.tr()));
}

class _ShareCopy {
  const _ShareCopy(this.code);
  final String code;
  String pick(String en, String hindi, String bengali) {
    final catalog = CodegenLoader.mapLocales[code];
    final translated = catalog?[en];
    if (translated is String && translated.isNotEmpty) return translated;
    return code == 'hi'
        ? hindi
        : code == 'bn'
        ? bengali
        : en;
  }

  String get chooseShareLanguage => pick(
    'Choose app language',
    'जानकारी साझा करने की भाषा चुनें',
    'তথ্য শেয়ার করার ভাষা বেছে নিন',
  );
  String get loanDetails => pick('Loan details', 'लोन का विवरण', 'ঋণের বিবরণ');
  String detailsFor(String name) {
    final template =
        CodegenLoader.mapLocales[code]?['loanDetailsFor'] as String?;
    return (template ?? 'Loan details for {name}').replaceAll('{name}', name);
  }

  String get borrower => pick('Borrower', 'उधारकर्ता', 'ঋণগ্রহীতা');
  String get phone => pick('Phone', 'फ़ोन', 'ফোন');
  String get address => pick('Address', 'पता', 'ঠিকানা');
  String get relativeName =>
      pick('Relative Name', 'रिश्तेदार का नाम', 'আত্মীয়ের নাম');
  String get mortgageName =>
      pick('Mortgage material', 'गिरवी वस्तु', 'বন্ধকী বস্তু');
  String get weight => pick('Weight', 'वज़न', 'ওজন');
  String get loanAmount =>
      pick('Principal amount', 'लोन की राशि', 'ঋণের পরিমাণ');
  String get interest => pick('Interest', 'ब्याज', 'সুদ');
  String get mortgageTerm =>
      pick('Mortgage term', 'गिरवी अवधि', 'বন্ধকের মেয়াদ');
  String get years => pick('years', 'वर्ष', 'বছর');
  String get days => pick('days', 'दिन', 'দিন');
  String yearCount(int count) => _template('yearsCount', count, years);
  String dayCount(int count) => _template('daysCount', count, days);
  String get lockInPeriod =>
      pick('Lock-in period', 'लॉक-इन अवधि', 'লক-ইন সময়কাল');
  String get until => pick('until', 'तक', 'পর্যন্ত');
  String get earlyRedemptionCharge => pick(
    'Early redemption charge',
    'समय से पहले छुड़ाने का शुल्क',
    'আগে ছাড়ানোর ফি',
  );
  String get beforeThisDate => pick(
    'if redeemed before this date',
    'इस तारीख से पहले छुड़ाने पर',
    'এই তারিখের আগে ছাড়ালে',
  );
  String estimatedDue(String date) =>
      '${pick('COLLECTABLE AMOUNT', 'अनुमानित देय राशि', 'আনুমানিক বকেয়া')} ($date)';
  String get status => pick('Status', 'स्थिति', 'অবস্থা');
  String get active => pick('Active', 'सक्रिय', 'সক্রিয়');
  String get completed => pick('Completed', 'पूर्ण', 'সম্পন্ন');
  String get created => pick('Created', 'बनाया गया', 'তৈরি হয়েছে');
  String get receivedBy =>
      pick('Item received by', 'प्राप्तकर्ता', 'গ্রহণকারী');
  String get amountReceived =>
      pick('Amount received', 'प्राप्त राशि', 'প্রাপ্ত পরিমাণ');
  String get additionalDetails =>
      pick('Additional details', 'अतिरिक्त विवरण', 'অতিরিক্ত বিবরণ');
  String get termsAndConditions =>
      pick('Terms and conditions', 'नियम और शर्तें', 'শর্তাবলি');
  String get notRecorded =>
      pick('Not recorded', 'दर्ज नहीं', 'রেকর্ড করা হয়নি');
  String get sentVia =>
      '${pick('Sent via :', 'इसके द्वारा भेजा गया:', 'এর মাধ্যমে পাঠানো:')} LoanX';
  String interestType(InterestType type) => type == InterestType.simple
      ? pick('Simple', 'साधारण', 'সরল')
      : pick('Compound', 'चक्रवृद्धि', 'চক্রবৃদ্ধি');

  String _template(String key, int count, String unit) {
    final template = CodegenLoader.mapLocales[code]?[key] as String?;
    return template
            ?.replaceAll('{count}', '$count')
            .replaceAll('{years}', '$count') ??
        '$count $unit';
  }

  String systemValue(String value) {
    const keys = {
      'Husband': 'systemHusband',
      'Father': 'systemFather',
      'Wife': 'systemWife',
      'Ring': 'systemRing',
      'Anklet': 'systemAnklet',
      'Bracelet': 'systemBracelet',
      'Armlet': 'systemArmlet',
      'Chain': 'systemChain',
      'Ear-Ring': 'systemEarRing',
      'Head-Locket': 'systemHeadLocket',
      'Medal': 'systemMedal',
      'Necklace': 'systemNecklace',
      'Locket': 'systemLocket',
      'Neck band': 'systemNeckBand',
      'Gram': 'systemGram',
      'Kilogram': 'systemKilogram',
      'Milligram': 'systemMilligram',
      'Tola': 'systemTola',
    };
    final key = keys[value];
    return key == null
        ? value
        : CodegenLoader.mapLocales[code]?[key] as String? ?? value;
  }
}

_ShareCopy _shareCopy(Locale locale) => _ShareCopy(
  CodegenLoader.mapLocales.containsKey(locale.languageCode)
      ? locale.languageCode
      : 'en',
);
