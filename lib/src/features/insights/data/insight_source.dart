import '../../../core/access/effective_permissions.dart';
import 'insight.dart';

/// A single rule that may contribute a card.
///
/// Evaluation is synchronous and pure — everything a source needs is already
/// in the [InsightContext], which keeps sources trivially testable and means
/// re-ranking on new data costs nothing.
///
/// [isAvailable] is the permission gate: a source whose grants the user does
/// not hold is never evaluated, so a card can't leak data the access-control
/// console hasn't granted. Sources only ever read.
abstract interface class InsightSource {
  String get id;

  bool isAvailable(EffectivePermissions permissions);

  /// Returns null when this rule has nothing worth saying right now.
  Insight? evaluate(InsightContext context);
}
