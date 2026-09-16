import 'dart:async';

import 'package:tostore/tostore.dart';
import 'settings_store.dart';

enum ConflictAlgorithm { abort, ignore, replace }

class DatabaseException implements Exception {
  const DatabaseException(this.message);
  final String message;
  @override
  String toString() => 'DatabaseException: $message';
}

abstract interface class DatabaseExecutor {
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  });
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  });
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  });
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs});
}

/// Storage port consumed by the application layer.  No UI, provider, or
/// domain service should depend on ToStore (or any future database SDK)
/// directly; replace [LoanxDatabase] with another implementation to change
/// the persistence engine.
abstract interface class LoanxDatabasePort implements DatabaseExecutor {
  Future<T> transaction<T>(Future<T> Function(DatabaseExecutor tx) action);
  LoanxBatch batch();
  Future<void> flush();
  Future<void> close();
  Future<int> getVersion();
  Future<void> setVersion(int version);
  Future<String> backup({bool compress = true});
  Future<bool> restore(String path);
  Future<dynamic> getValue(String key, {bool isGlobal = false});
  Future<void> setValue(String key, dynamic value, {bool isGlobal = false});
  Future<void> removeValue(String key, {bool isGlobal = false});
}

typedef Database = LoanxDatabasePort;

/// Small compatibility boundary that keeps the domain layer independent from
/// ToStore's builders. New repositories can use [store] for watch/query-cache,
/// cursor pagination and other native capabilities.
final class LoanxDatabase implements LoanxDatabasePort {
  LoanxDatabase(this.store);
  final ToStore store;

  static const _queryPageSize = 1000;

  static const _numericIdTables = {
    'loans',
    'loanChanges',
    'familyRelations',
    'mortgageMaterials',
    'weightUnits',
  };

  Object? _toStoreValue(String table, String field, Object? value) {
    if (value == null) return null;
    if ((field == 'id' && _numericIdTables.contains(table)) ||
        (field == 'loanId') ||
        field == 'familyRelationId' ||
        field == 'mortgageMaterialId') {
      return value.toString();
    }
    return value;
  }

  Map<String, Object?> _toStoreRow(String table, Map<String, Object?> row) => {
    for (final entry in row.entries)
      if (entry.value != null)
        entry.key: _toStoreValue(table, entry.key, entry.value),
  };

  Map<String, Object?> _fromStoreRow(String table, Map<String, dynamic> row) {
    final result = <String, Object?>{...row};
    if (_numericIdTables.contains(table)) {
      for (final field in const [
        'id',
        'loanId',
        'familyRelationId',
        'mortgageMaterialId',
      ]) {
        final value = result[field];
        if (value is String) result[field] = int.tryParse(value) ?? value;
      }
    }
    return result;
  }

  dynamic _conditions(
    dynamic builder,
    String table,
    String? clause,
    List<Object?> args,
  ) {
    if (clause == null || clause.trim().isEmpty) return builder;
    var index = 0;
    for (var part in clause.split(RegExp(r'\s+AND\s+', caseSensitive: false))) {
      part = part.trim();
      final lower = RegExp(
        r'^LOWER\((\w+)\)\s*=\s*LOWER\(\?\)$',
        caseSensitive: false,
      ).firstMatch(part);
      if (lower != null) {
        builder = builder.where(
          lower.group(1)!,
          '=',
          args[index++].toString().toLowerCase(),
        );
        continue;
      }
      final match = RegExp(
        r'^(\w+)\s*(=|!=|<>|>=|<=|>|<|LIKE)\s*\?$',
        caseSensitive: false,
      ).firstMatch(part);
      if (match == null || index >= args.length) {
        throw DatabaseException('Unsupported query predicate: $clause');
      }
      final field = match.group(1)!;
      builder = builder.where(
        field,
        match.group(2)!.toUpperCase(),
        _toStoreValue(table, field, args[index++]),
      );
    }
    return builder;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    Future<dynamic> readPage(int pageLimit, int pageOffset) async {
      dynamic builder = store.query(table);
      builder = _conditions(builder, table, where, whereArgs ?? const []);
      if (columns != null) builder = builder.select(columns);
      if (orderBy != null) {
        for (final item in orderBy.split(',')) {
          final bits = item.trim().split(RegExp(r'\s+'));
          final descending = bits.any((v) => v.toUpperCase() == 'DESC');
          builder = descending
              ? builder.orderByDesc(bits.first)
              : builder.orderByAsc(bits.first);
        }
      }
      builder = builder.limit(pageLimit);
      if (pageOffset > 0) builder = builder.offset(pageOffset);
      return await builder;
    }

    final rows = <Map<String, Object?>>[];
    var pageOffset = offset ?? 0;
    var remaining = limit;
    while (remaining == null || remaining > 0) {
      final pageLimit = remaining == null
          ? _queryPageSize
          : remaining.clamp(1, _queryPageSize);
      final dynamic result = await readPage(pageLimit, pageOffset);
      if (result.hasErrors == true) {
        throw DatabaseException(result.message.toString());
      }
      final data = result.data as List<dynamic>;
      rows.addAll([
        for (final dynamic row in data)
          _fromStoreRow(table, Map<String, dynamic>.from(row as Map)),
      ]);
      if (data.length < pageLimit) break;
      pageOffset += data.length;
      if (remaining != null) remaining -= data.length;
    }
    return rows;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final row = _toStoreRow(table, values);
    final dynamic result = conflictAlgorithm == ConflictAlgorithm.replace
        ? await store.upsert(table, row)
        : await store.insert(table, row);
    if (result.hasErrors == true) {
      if (conflictAlgorithm == ConflictAlgorithm.ignore) return 0;
      throw DatabaseException(result.message.toString());
    }
    final key = result.firstPrimaryKey?.toString();
    return int.tryParse(key ?? '') ?? result.successCount as int;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    dynamic builder = store.update(table, _toStoreRow(table, values));
    builder = _conditions(builder, table, where, whereArgs ?? const []);
    if (where == null) builder = builder.allowUpdateAll();
    final dynamic result = await builder;
    if (result.hasErrors == true) {
      if (result.message.toString().contains('No matching records')) return 0;
      throw DatabaseException(result.message.toString());
    }
    return result.successCount as int;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    dynamic builder = store.delete(table);
    builder = _conditions(builder, table, where, whereArgs ?? const []);
    if (where == null) builder = builder.allowDeleteAll();
    final dynamic result = await builder;
    if (result.hasErrors == true) {
      throw DatabaseException(result.message.toString());
    }
    return result.successCount as int;
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(DatabaseExecutor tx) action,
  ) async {
    T? value;
    Object? actionError;
    StackTrace? actionStack;
    final result = await store.transaction(() async {
      try {
        value = await action(this);
      } catch (error, stack) {
        actionError = error;
        actionStack = stack;
        rethrow;
      }
    });
    if (actionError != null) {
      Error.throwWithStackTrace(actionError!, actionStack!);
    }
    if (result.hasErrors) {
      throw DatabaseException(result.statuses.map((s) => s.message).join('; '));
    }
    // `persistRecoveryOnCommit` protects the recovery journal, but it does
    // not necessarily flush the table data buffers to durable storage. A
    // process kill immediately after a successful loan or repayment write
    // could otherwise make the record disappear on the next launch.
    await flush();
    return value as T;
  }

  @override
  LoanxBatch batch() => LoanxBatch(this);
  @override
  Future<void> flush() => store.flush();
  @override
  Future<void> close() => store.close();
  @override
  Future<int> getVersion() => store.getVersion();
  @override
  Future<void> setVersion(int version) => store.setVersion(version);

  @override
  Future<String> backup({bool compress = true}) =>
      store.backup(compress: compress);

  @override
  Future<bool> restore(String path) => store.restore(path);

  @override
  Future<dynamic> getValue(String key, {bool isGlobal = false}) =>
      store.getValue(key, isGlobal: isGlobal);

  @override
  Future<void> setValue(
    String key,
    dynamic value, {
    bool isGlobal = false,
  }) async {
    final result = await store.setValue(key, value, isGlobal: isGlobal);
    if (result.hasErrors) throw DatabaseException(result.message);
  }

  @override
  Future<void> removeValue(String key, {bool isGlobal = false}) async {
    final result = await store.removeValue(key, isGlobal: isGlobal);
    if (result.hasErrors) throw DatabaseException(result.message);
  }
}

/// ToStore implementation of the settings port. Kept separate from the
/// application facade so changing databases does not affect AppSettings callers.
final class ToStoreSettingsStore implements SettingsStore {
  ToStoreSettingsStore(this.database);
  final ToStore database;

  @override
  Future<Object?> read(String key) => database.getValue(key);

  @override
  Future<void> write(String key, Object? value) async {
    final result = await database.setValue(key, value);
    if (result.hasErrors) throw DatabaseException(result.message);
  }

  @override
  Future<void> remove(String key) async {
    final result = await database.removeValue(key);
    if (result.hasErrors) throw DatabaseException(result.message);
  }

  @override
  Future<void> flush() => database.flush();
}

final class LoanxBatch {
  LoanxBatch(this._database);
  final LoanxDatabase _database;
  final List<Future<Object?> Function()> _operations = [];

  void insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(
      () =>
          _database.insert(table, values, conflictAlgorithm: conflictAlgorithm),
    );
  }

  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _operations.add(
      () => _database.delete(table, where: where, whereArgs: whereArgs),
    );
  }

  Future<List<Object?>> commit({bool continueOnError = false}) async {
    final values = <Object?>[];
    await _database.transaction((_) async {
      for (final operation in _operations) {
        try {
          values.add(await operation());
        } catch (_) {
          if (!continueOnError) rethrow;
          values.add(null);
        }
      }
    });
    return values;
  }
}
