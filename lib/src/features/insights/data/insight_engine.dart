import '../../../core/access/effective_permissions.dart';
import 'insight.dart';
import 'insight_source.dart';

/// Ranks candidate insights. No model, no network — the "intelligence" is
/// four terms: the relevance each source computes for itself, a novelty bonus
/// when the underlying data has changed since the card was last shown, and a
/// fatigue penalty that stops one card from winning forever.
///
/// Deterministic by construction, so its behaviour can be asserted in tests
/// rather than eyeballed.
class InsightEngine {
  InsightEngine({
    required this.sources,
    this.noveltyBonus = 0.2,
    this.fatiguePenalty = 0.1,
    this.fatigueCeiling = 8,
  });

  final List<InsightSource> sources;
  final double noveltyBonus;
  final double fatiguePenalty;

  /// Caps the fatigue term so a long session can't drive scores arbitrarily
  /// negative and freeze the ordering.
  final int fatigueCeiling;

  final _shownCount = <String, int>{};
  final _lastSignature = <String, String>{};

  /// Highest-scoring first. Sources the user lacks grants for are skipped
  /// before evaluation.
  List<Insight> rank(InsightContext context, EffectivePermissions permissions) {
    final scored = <({Insight insight, double score})>[];

    for (final source in sources) {
      if (!source.isAvailable(permissions)) continue;

      final insight = source.evaluate(context);
      if (insight == null) continue;

      final seen = _lastSignature[source.id];
      final isNovel = seen != null && seen != insight.signature;
      final shown = (_shownCount[source.id] ?? 0).clamp(0, fatigueCeiling);

      final score =
          insight.relevance +
          (isNovel ? noveltyBonus : 0) -
          fatiguePenalty * shown;

      scored.add((insight: insight, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return [for (final entry in scored) entry.insight];
  }

  /// Records that a card was surfaced, feeding the novelty and fatigue terms
  /// of the next ranking pass.
  void markShown(Insight insight) {
    _shownCount[insight.sourceId] = (_shownCount[insight.sourceId] ?? 0) + 1;
    _lastSignature[insight.sourceId] = insight.signature;
  }
}
