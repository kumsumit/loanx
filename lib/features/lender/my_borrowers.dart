import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/currency_presentation.dart';

class BorrowerSummary {
  const BorrowerSummary({
    required this.name,
    required this.connected,
    required this.loanCount,
    required this.outstanding,
  });

  final String name;
  final bool connected;
  final int loanCount;
  final Map<String, num> outstanding;
}

final myBorrowersProvider = FutureProvider<List<BorrowerSummary>>((ref) async {
  ref.watch(loanListProvider);
  return loadMyBorrowers(await ref.read(dBProvider.future));
});

/// Only group by owner-scoped Party IDs; names/phone numbers are not identity
/// keys, and a connected account must never inherit a private contact.
Future<List<BorrowerSummary>> loadMyBorrowers(Database db) async {
  final owners = await db.query('localOwners');
  if (owners.length != 1) return const [];
  final ownerId = owners.single['id'];
  final selfPartyId = owners.single['selfPartyId'];
  if (ownerId is! String || selfPartyId is! String) return const [];
  final rows = await db.query(
    Loan.tableName,
    where: 'ownerId = ? AND lenderPartyId = ?',
    whereArgs: [ownerId, selfPartyId],
  );
  final grouped = <String, List<Loan>>{};
  for (final row in rows) {
    final borrowerId = row['borrowerPartyId'];
    if (borrowerId is! String || borrowerId.isEmpty) continue;
    grouped.putIfAbsent(borrowerId, () => []).add(Loan.fromJson(row));
  }
  final result = <BorrowerSummary>[];
  for (final entry in grouped.entries) {
    final parties = await db.query(
      'parties',
      where: 'ownerId = ? AND id = ? AND status = ?',
      whereArgs: [ownerId, entry.key, 'ACTIVE'],
      limit: 1,
    );
    if (parties.isEmpty) continue;
    final party = parties.single;
    final amounts = <String, num>{};
    for (final loan in entry.value.where((loan) => !loan.isFinished())) {
      amounts.update(
        loan.currency,
        (amount) => amount + loan.calculateCollectable(),
        ifAbsent: loan.calculateCollectable,
      );
    }
    result.add(
      BorrowerSummary(
        name: party['displayName'] as String? ?? '',
        connected:
            party['userId'] is String && (party['userId'] as String).isNotEmpty,
        loanCount: entry.value.length,
        outstanding: amounts,
      ),
    );
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

class MyBorrowers extends ConsumerWidget {
  const MyBorrowers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(myBorrowersProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            Center(child: Text('Borrowers could not be loaded'.tr())),
        data: (borrowers) => borrowers.isEmpty
            ? Center(child: Text('No borrowers yet'.tr()))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: borrowers.length,
                itemBuilder: (context, index) {
                  final item = borrowers[index];
                  final totals = item.outstanding.entries
                      .map(
                        (entry) =>
                            CurrencyPresentation.format(entry.value, entry.key),
                      )
                      .join(' · ');
                  return Card(
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.connected ? 'Connected'.tr() : 'External'.tr()} · '
                        '${item.loanCount} ${'loans'.tr()}',
                      ),
                      trailing: totals.isEmpty ? null : Text(totals),
                    ),
                  );
                },
              ),
      );
}
