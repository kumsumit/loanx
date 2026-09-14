import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppSettings persists through the ToStore KV port', () async {
    await DatabaseHelper.instance.close();
    await AppSettings.initForTesting(Directory.systemTemp);
    AppSettings.putInterestRate(7.5);
    await AppSettings.flush();
    expect(AppSettings.getInterestRate(), 7.5);
  });

  test('SQL-style unbounded reads are paginated without losing rows', () async {
    final db = await DatabaseHelper.instance.openMemory(
      name: 'unbounded-query-test',
    );
    for (var index = 0; index < 1001; index++) {
      await db.insert('familyRelations', {
        'name': 'Relation $index',
        'isAddedByUser': 1,
      });
    }

    final rows = await db.query('familyRelations', orderBy: 'name ASC');

    expect(rows, hasLength(1001));
    await db.close();
  });

  test('model table names match the case-sensitive ToStore schema', () async {
    final db = await DatabaseHelper.instance.openMemory(
      name: 'model-table-name-test',
    );

    await db.insert(MortgageMaterial.tableName, {
      'name': 'Ring',
      'isAddedByUser': 0,
    });

    expect(await db.query(MortgageMaterial.tableName), hasLength(1));
    await db.close();
  });
}
