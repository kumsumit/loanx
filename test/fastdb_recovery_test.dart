import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/fastdb.dart';

void main() {
  test(
    'FastDB recovers its last valid file after primary corruption',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'loanx-fastdb-test-',
      );
      try {
        await FastDB.initForTesting(directory);
        FastDB.putInterestRate(2.5);
        await FastDB.flush();
        FastDB.putInterestRate(3.5);
        await FastDB.flush();

        await File(
          FastDB.primaryFilePathForTesting,
        ).writeAsBytes([1, 2, 3], flush: true);
        await FastDB.reloadForTesting();

        expect(FastDB.getInterestRate(), 2.5);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('queued FastDB writes finish in request order', () async {
    final directory = await Directory.systemTemp.createTemp(
      'loanx-fastdb-queue-test-',
    );
    try {
      await FastDB.initForTesting(directory);
      FastDB.putInterestRate(4.5);
      final firstWrite = FastDB.flush();
      FastDB.putInterestRate(5.5);
      final secondWrite = FastDB.flush();
      await Future.wait([firstWrite, secondWrite]);

      await FastDB.reloadForTesting();

      expect(FastDB.getInterestRate(), 5.5);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('a complete temporary write is promoted after interruption', () async {
    final directory = await Directory.systemTemp.createTemp(
      'loanx-fastdb-interrupted-test-',
    );
    try {
      await FastDB.initForTesting(directory);
      FastDB.putInterestRate(6.5);
      await FastDB.flush();
      FastDB.putInterestRate(7.5);
      await FastDB.flush();

      final latestBytes = await File(
        FastDB.primaryFilePathForTesting,
      ).readAsBytes();
      await File(
        FastDB.backupFilePathForTesting,
      ).copy(FastDB.primaryFilePathForTesting);
      await File(
        FastDB.temporaryFilePathForTesting,
      ).writeAsBytes(latestBytes, flush: true);

      await FastDB.reloadForTesting();

      expect(FastDB.getInterestRate(), 7.5);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('FastDB falls back to the second backup generation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'loanx-fastdb-older-backup-test-',
    );
    try {
      await FastDB.initForTesting(directory);
      for (final rate in [1.5, 2.5, 3.5]) {
        FastDB.putInterestRate(rate);
        await FastDB.flush();
      }

      await File(
        FastDB.primaryFilePathForTesting,
      ).writeAsBytes([1], flush: true);
      await File(
        FastDB.backupFilePathForTesting,
      ).writeAsBytes([2], flush: true);
      await FastDB.reloadForTesting();

      expect(FastDB.getInterestRate(), 1.5);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('FastDB never silently resets unreadable encrypted data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'loanx-fastdb-key-loss-test-',
    );
    try {
      await FastDB.initForTesting(directory);
      FastDB.putInterestRate(8.5);
      await FastDB.flush();

      await expectLater(
        FastDB.initForTesting(directory, keyOffset: 1),
        throwsA(isA<FastDbRecoveryException>()),
      );
      expect(await File(FastDB.primaryFilePathForTesting).exists(), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
