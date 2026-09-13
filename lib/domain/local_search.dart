enum SearchEntityType { loan, party, repayment, collateral, message, answer }

enum SearchMode { structured, fullText, fuzzy, fallback }

class LocalSearchResult {
  const LocalSearchResult({
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.subtitle,
    required this.matchReason,
    required this.score,
  });
  final SearchEntityType entityType;
  final String entityId, title, subtitle, matchReason;
  final int score;
}

class LocalSearchResponse {
  const LocalSearchResponse({
    required this.query,
    required this.mode,
    required this.results,
    required this.interpreted,
    this.explanation,
  });
  final String query;
  final SearchMode mode;
  final List<LocalSearchResult> results;
  final bool interpreted;
  final String? explanation;
}
