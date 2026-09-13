import '../db/tostore_database.dart';
import '../domain/local_search.dart';

/// Read-only, offline search planner. Exact financial predicates are parsed
/// into typed filters and evaluated without generated SQL or an online model.
final class LocalSearchService {
  LocalSearchService(
    this.database, {
    required this.ownerId,
    required this.selfPartyId,
  });
  final Database database;
  final String ownerId, selfPartyId;
  static const int maximumResults = 50;

  Future<LocalSearchResponse> search(
    String raw, {
    int limit = 20,
    DateTime? now,
  }) async {
    if (limit < 1 || limit > maximumResults) {
      throw ArgumentError('Invalid result limit');
    }
    final query = _normalize(raw);
    if (query.isEmpty || query.length > 300) {
      return LocalSearchResponse(
        query: raw,
        mode: SearchMode.fallback,
        results: const [],
        interpreted: false,
        explanation: 'Enter a shorter search query.',
      );
    }
    final at = (now ?? DateTime.now()).toUtc();
    final parties = await database.query(
      'parties',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      limit: 1000,
    );
    final loans = await database.query(
      'loans',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      limit: 5000,
    );
    final events = await database.query(
      'financialEvents',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      limit: 5000,
    );
    final messages = await database.query(
      'messages',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      limit: 2000,
    );
    final structured = _isStructured(query);
    final threshold = _amountThreshold(query);
    final overdue = query.contains('overdue');
    final dueThisMonth = query.contains('due this month');
    final closed = RegExp(r'\b(?:old|closed) loans?\b').hasMatch(query);
    final gold = query.contains('gold') || query.contains('bangle');
    final repayment =
        query.contains('repayment') ||
        query.contains('paid') ||
        query.contains('cash');
    final owing = query.contains('how much do i owe');
    final owedMost = query.contains('who owes me the most');
    if (owing || owedMost) {
      final total = _aggregate(loans, events, borrower: owing, most: owedMost);
      return LocalSearchResponse(
        query: raw,
        mode: SearchMode.structured,
        interpreted: true,
        explanation:
            'Calculated from owner-scoped local loan and repayment records.',
        results: total == null ? const [] : [total],
      );
    }
    final output = <LocalSearchResult>[];
    if (!repayment) {
      for (final loan in loans) {
        if (!_loanMatches(
          loan,
          query,
          at,
          threshold,
          overdue,
          dueThisMonth,
          closed,
          gold,
        )) {
          continue;
        }
        final name = (loan['depositorName'] ?? 'Loan').toString();
        output.add(
          LocalSearchResult(
            entityType: SearchEntityType.loan,
            entityId: (loan['uid'] ?? loan['id']).toString(),
            title: name,
            subtitle: '${loan['currency'] ?? 'INR'} ${loan['loanAmount']}',
            matchReason: structured
                ? 'Matched exact loan filters'
                : 'Matched loan text',
            score: structured ? 100 : 70,
          ),
        );
      }
    }
    for (final p in parties) {
      final name = p['displayName'].toString();
      final score = _similarity(query, _normalize(name));
      if (!structured && (query.contains(_normalize(name)) || score >= 65)) {
        output.add(
          LocalSearchResult(
            entityType: SearchEntityType.party,
            entityId: p['id'].toString(),
            title: name,
            subtitle: p['userId'] == null
                ? 'External party'
                : 'Connected party',
            matchReason: query.contains(_normalize(name))
                ? 'Name match'
                : 'Similar name',
            score: score,
          ),
        );
      }
    }
    if (repayment) {
      final amount = _mentionedAmount(query);
      for (final e in events) {
        if (e['type'] != 'repayment' ||
            (amount != null &&
                BigInt.tryParse(e['amountMinor'].toString()) != amount)) {
          continue;
        }
        if (query.contains('cash') && e['paymentMethod'] != 'cash') continue;
        output.add(
          LocalSearchResult(
            entityType: SearchEntityType.repayment,
            entityId: e['id'].toString(),
            title: 'Repayment',
            subtitle: '${e['currency']} ${e['amountMinor']}',
            matchReason: 'Matched exact repayment fields',
            score: 100,
          ),
        );
      }
    }
    if (!structured) {
      for (final m in messages) {
        final body = _normalize(m['body'].toString());
        if (body.contains(query)) {
          output.add(
            LocalSearchResult(
              entityType: SearchEntityType.message,
              entityId: m['id'].toString(),
              title: 'Conversation message',
              subtitle: m['body'].toString(),
              matchReason: 'Message text match',
              score: 60,
            ),
          );
        }
      }
    }
    output.sort((a, b) => b.score.compareTo(a.score));
    return LocalSearchResponse(
      query: raw,
      mode: structured ? SearchMode.structured : SearchMode.fullText,
      results: output.take(limit).toList(growable: false),
      interpreted: structured || output.isNotEmpty,
      explanation: output.isEmpty ? 'No matching local record found.' : null,
    );
  }

  bool _loanMatches(
    Map<String, Object?> l,
    String q,
    DateTime at,
    BigInt? threshold,
    bool overdue,
    bool dueMonth,
    bool closed,
    bool gold,
  ) {
    final finished = l['dateFinished']?.toString().isNotEmpty ?? false;
    if (closed && !finished) return false;
    if (!closed && q.contains('active loan') && finished) return false;
    final created = DateTime.tryParse(l['dateCreated']?.toString() ?? '');
    final years = (l['mortgageTermYears'] as num?)?.toInt() ?? 5;
    final due = created == null
        ? null
        : DateTime.utc(created.year + years, created.month, created.day);
    if (overdue && (finished || due == null || !due.isBefore(at))) return false;
    if (dueMonth &&
        (due == null || due.year != at.year || due.month != at.month)) {
      return false;
    }
    final minor = _loanMinor(l);
    if (threshold != null && minor <= threshold) return false;
    if (gold) {
      final text = _normalize(
        '${l['additionalDetails']} ${l['termsAndConditions']} ${l['weight']}',
      );
      if (!text.contains('gold') && (l['weight'] as num? ?? 0) <= 0) {
        return false;
      }
    }
    if (_isStructured(q)) return true;
    final text = _normalize(
      '${l['depositorName']} ${l['additionalDetails']} ${l['termsAndConditions']} ${l['address']}',
    );
    return text.contains(q) ||
        q.split(' ').where((x) => x.length > 2).any(text.contains);
  }

  LocalSearchResult? _aggregate(
    List<Map<String, Object?>> loans,
    List<Map<String, Object?>> events, {
    required bool borrower,
    required bool most,
  }) {
    final repayments = <String, BigInt>{};
    for (final e in events) {
      final id = e['loanUid'].toString();
      final amount =
          BigInt.tryParse(e['amountMinor'].toString()) ?? BigInt.zero;
      repayments[id] =
          (repayments[id] ?? BigInt.zero) +
          (e['type'] == 'reversal' ? -amount : amount);
    }
    BigInt total = BigInt.zero;
    Map<String, Object?>? winner;
    BigInt high = BigInt.from(-1);
    for (final l in loans) {
      if (l['dateFinished'] != null) continue;
      final isBorrower = l['borrowerPartyId'] == selfPartyId;
      if (borrower != isBorrower) continue;
      final value =
          (_loanMinor(l) - (repayments[l['uid'].toString()] ?? BigInt.zero));
      final safe = value < BigInt.zero ? BigInt.zero : value;
      total += safe;
      if (safe > high) {
        high = safe;
        winner = l;
      }
    }
    if (most && winner == null) return null;
    return LocalSearchResult(
      entityType: SearchEntityType.answer,
      entityId: most
          ? (winner!['uid'] ?? winner['id']).toString()
          : 'aggregate:owed',
      title: most
          ? (winner!['depositorName'] ?? 'Borrower').toString()
          : 'Total outstanding',
      subtitle: '${most ? winner!['currency'] : 'INR'} ${most ? high : total}',
      matchReason: 'Deterministic balance aggregation',
      score: 100,
    );
  }

  static BigInt _loanMinor(Map<String, Object?> l) =>
      BigInt.from((((l['loanAmount'] as num?)?.toDouble() ?? 0) * 100).round());
  static bool _isStructured(String q) =>
      q.contains('overdue') ||
      q.contains('due this month') ||
      q.contains('above ') ||
      q.contains('more than') ||
      q.contains('gold') ||
      q.contains('repayment') ||
      q.contains('how much do i owe') ||
      q.contains('who owes me');
  static BigInt? _amountThreshold(String q) {
    final m = RegExp(
      r'(?:above|more than|greater than)\s+(?:rs\.?\s*|₹\s*)?([\d,.]+|one lakh|1 lakh)',
    ).firstMatch(q);
    if (m == null) return null;
    return _parseAmount(m.group(1)!);
  }

  static BigInt? _mentionedAmount(String q) {
    final m = RegExp(
      r'(?:rs\.?\s*|₹\s*)?([\d,]+)(?:\s+made|\s+in|\s+cash|$)',
    ).firstMatch(q);
    return m == null ? null : _parseAmount(m.group(1)!);
  }

  static BigInt? _parseAmount(String v) {
    final x = v.replaceAll(',', '').trim();
    if (x == 'one lakh' || x == '1 lakh') return BigInt.from(10000000);
    final n = num.tryParse(x);
    return n == null ? null : BigInt.from((n * 100).round());
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}₹.]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  static int _similarity(String a, String b) {
    if (a == b) return 100;
    if (a.isEmpty || b.isEmpty) return 0;
    final d = List.generate(a.length + 1, (i) => i);
    for (var j = 1; j <= b.length; j++) {
      var prev = d[0];
      d[0] = j;
      for (var i = 1; i <= a.length; i++) {
        final old = d[i];
        d[i] = [
          d[i] + 1,
          d[i - 1] + 1,
          prev + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
        prev = old;
      }
    }
    return (100 *
            (1 - d[a.length] / (a.length > b.length ? a.length : b.length)))
        .round();
  }
}
