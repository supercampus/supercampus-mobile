import '../../authentication/data/auth_repository.dart';
import '../../authentication/data/backend_auth_repository.dart';
import '../../hostel/data/backend_hostel_repository.dart';
import 'settings_api.dart';

/// Facts about the signed-in person that the session does not carry. Every
/// field is optional: a missing value is left out of the profile, never
/// guessed.
class ProfileExtras {
  const ProfileExtras({
    this.institution,
    this.programme,
    this.academicYear,
    this.residency,
    this.hostel,
    this.block,
    this.room,
  });

  final String? institution;
  final String? programme;
  final String? academicYear;

  /// `hosteller` or `day_scholar`, as the server reports it.
  final String? residency;
  final String? hostel;
  final String? block;
  final String? room;

  bool get isHosteller => residency == 'hosteller';

  static const empty = ProfileExtras();
}

abstract interface class AccountRepository {
  /// `POST /api/v1/auth/change-password`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// `POST /api/auth/forgot-password` for [email].
  Future<void> sendPasswordReset(String email);

  /// Best effort: institution from `GET /api/auth/me`; programme, year and
  /// residency from `GET /api/v1/operations/hostel/overview` when the caller
  /// has a student record. Never throws.
  Future<ProfileExtras> loadProfileExtras();
}

class BackendAccountRepository implements AccountRepository {
  BackendAccountRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    SettingsApiClient? api,
    AuthRepository? auth,
  }) : _api =
           api ??
           SettingsApiClient(
             baseUrl: baseUrl,
             accessTokenProvider: accessTokenProvider,
           ),
       _auth = auth ?? BackendAuthRepository(baseUrl: baseUrl),
       _hostel = BackendHostelRepository(
         baseUrl: baseUrl,
         accessTokenProvider: accessTokenProvider,
         studentName: '',
         studentCode: '',
       );

  final SettingsApiClient _api;
  final AuthRepository _auth;
  final BackendHostelRepository _hostel;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.send(
      'POST',
      '/api/v1/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      fallbackError: 'Your password could not be changed. Try again.',
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordReset(email);
    } on AuthenticationException catch (error) {
      throw SettingsApiException(error.message);
    }
  }

  @override
  Future<ProfileExtras> loadProfileExtras() async {
    String? institution;
    Map<String, dynamic> student = const {};
    await Future.wait([
      () async {
        try {
          final data = await _api.send(
            'GET',
            '/api/auth/me',
            fallbackError: '',
          );
          if (data is Map) {
            final me = data['student'];
            if (me is Map) {
              final tenant = me['tenant'];
              institution =
                  cleanText(me['fullCollege']) ??
                  (tenant is Map ? cleanText(tenant['name']) : null) ??
                  cleanText(me['college']);
            }
          }
        } catch (_) {
          // Institution name is a nicety; the profile works without it.
        }
      }(),
      () async {
        try {
          final summary = await _hostel.loadStudentSummary();
          // Only a real student record carries `studentId`; for anyone else
          // the server answers a bare placeholder that must not be shown.
          if (cleanText(summary['studentId']) != null) student = summary;
        } catch (_) {
          // No academic summary for this account (or no access to it).
        }
      }(),
    ]);
    return ProfileExtras(
      institution: institution,
      programme: cleanText(student['programme']),
      academicYear: cleanText(student['academicYear']),
      residency: cleanText(student['residency']),
      hostel: cleanText(student['hostel']),
      block: cleanText(student['block']),
      room: cleanText(student['room']),
    );
  }
}
