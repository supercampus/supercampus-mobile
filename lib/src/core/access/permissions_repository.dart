import '../../features/authentication/data/auth_repository.dart';
import 'effective_permissions.dart';

/// Resolves the signed-in user's effective permissions.
///
/// The real implementation calls the admin console's API and hands the
/// response to [EffectivePermissions.fromJson] — the client never computes
/// grants itself, it only renders them. Hiding a card is UX, not security:
/// the same checks must run server-side on every write.
abstract interface class PermissionsRepository {
  Future<EffectivePermissions> loadFor(UserSession session);
}
