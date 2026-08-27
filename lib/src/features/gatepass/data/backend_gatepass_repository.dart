import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'gatepass_models.dart';
import 'gatepass_repository.dart';

class BackendGatepassRepository implements GatepassRepository {
  BackendGatepassRepository({
    required String baseUrl,
    String? accessToken,
    AccessTokenProvider? accessTokenProvider,
    required this.studentName,
    required this.email,
    required this.rollNumber,
    required this.department,
    http.Client? client,
    CampusPositionProvider? positionProvider,
  }) : assert(
         accessToken != null || accessTokenProvider != null,
         'Provide an access token or token provider.',
       ),
       _baseUri = _normalizeBaseUri(baseUrl),
       _accessToken = accessToken,
       _accessTokenProvider = accessTokenProvider,
       _positionProvider = positionProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final String? _accessToken;
  final AccessTokenProvider? _accessTokenProvider;
  final CampusPositionProvider? _positionProvider;
  final http.Client _client;
  final String studentName;
  final String email;
  final String rollNumber;
  final String department;

  Uri _uri(String path) => _baseUri.resolve(path);

  @override
  Future<GatepassStore> loadStore() async {
    // Start GPS immediately instead of waiting for the overview HTTP request.
    // On a cold start these are the two slowest operations and neither depends
    // on the other.
    final positionFuture = (_positionProvider ?? _currentCampusPosition)();
    Map<String, dynamic> data;
    String? overviewIssue;
    try {
      final overview = await _authorizedRequest(
        (headers) => _client.get(
          _uri('/api/v1/operations/gatepass/overview'),
          headers: headers,
        ),
      );
      data = _data(overview);
    } on GatepassUnavailableException {
      // The overview is the module's backbone, but a server that cannot answer
      // it at all should still let the reader in to see what else works.
      data = const <String, dynamic>{};
      overviewIssue =
          'Gatepass requests could not be refreshed. Pull back from the '
          'module and try again in a moment.';
    }
    // Everything below the overview is best-effort. Activating today's pass
    // needs the device's location and the campus fence's consent, and neither
    // is owed to a learner sitting at home — so a refusal there must not take
    // the requests and gate movements down with it.
    DailyAccessPass? dailyPass;
    String? dailyPassIssue;
    CampusMapLocation? mapLocation;
    var zone = CampusZone.unknown;
    try {
      final position = await positionFuture;
      final dailyResponse = await _authorizedRequest(
        (headers) => _client.post(
          _uri('/api/v1/operations/gatepass/daily-access'),
          headers: headers,
          body: jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracyMetres': position.accuracyMetres,
          }),
        ),
        json: true,
      );
      final daily = _data(dailyResponse);
      dailyPass = DailyAccessPass(
        id: _text(daily['id']),
        validOn: _date(daily['validOn']),
        validFrom: _date(daily['validFrom']),
        validUntil: _date(daily['validUntil']),
        qrPayload: _text(daily['qrPayload']),
      );
      final location = _map(daily['location']);
      final geofence = _map(daily['campusGeofence']);
      final studentLatitude = _number(location['latitude']);
      final studentLongitude = _number(location['longitude']);
      final campusLatitude = _number(geofence['latitude']);
      final campusLongitude = _number(geofence['longitude']);
      final radiusMetres = _number(geofence['radiusMetres']);
      if (studentLatitude != null &&
          studentLongitude != null &&
          campusLatitude != null &&
          campusLongitude != null &&
          radiusMetres != null) {
        mapLocation = CampusMapLocation(
          studentLatitude: studentLatitude,
          studentLongitude: studentLongitude,
          accuracyMetres: _number(location['accuracyMetres']) ?? 0,
          campusLatitude: campusLatitude,
          campusLongitude: campusLongitude,
          radiusMetres: radiusMetres,
        );
      }
      // A pass is the only proof of being inside the fence that the app can
      // honestly claim, because the fence is the API's to know.
      zone = CampusZone.inside;
    } on OutsideCampusException catch (error) {
      zone = CampusZone.outside;
      dailyPassIssue = error.message;
    } on GatepassException catch (error) {
      dailyPassIssue = error.message;
    } catch (_) {
      // Location can fail in ways the plugin does not model as one of ours —
      // a timeout with no fix, a platform channel error. The reader needs the
      // same sentence either way.
      dailyPassIssue =
          'Today\'s campus entry QR could not be generated. '
          'Check your location and try again.';
    }

    return GatepassStore(
      student: GatepassStudent(
        name: studentName,
        email: email,
        rollNumber: rollNumber.isEmpty ? 'Not assigned' : rollNumber,
        department: department.isEmpty ? 'Not assigned' : department,
        residency: StudentResidency.dayScholar,
        hostel: null,
        room: null,
        isOnCampus: zone == CampusZone.inside,
      ),
      workflow: _workflow,
      dailyPass: dailyPass,
      dailyPassIssue: dailyPassIssue ?? overviewIssue,
      mapLocation: mapLocation,
      zone: zone,
      requests: _list(
        data['requests'],
      ).map((value) => _request(_map(value))).toList(growable: false),
      visitors: const [],
      movements: _list(
        data['movements'],
      ).map((value) => _movement(_map(value))).toList(growable: false),
    );
  }

  Future<CampusPosition> _currentCampusPosition() async {
    final position = await _currentPosition();
    return (
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMetres: position.accuracy,
    );
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GatepassException(
        'Turn on location services to generate today\'s campus entry QR.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const GatepassException(
        'Location permission is required to generate today\'s campus entry QR.',
      );
    }
    // Android normally already has a recent fused fix. Reusing it makes the
    // Gatepass dashboard open immediately instead of displaying a full-screen
    // loader while the GPS radio starts from cold.
    final cached = await Geolocator.getLastKnownPosition();
    if (cached != null &&
        DateTime.now().difference(cached.timestamp).abs() <
            const Duration(minutes: 5) &&
        cached.accuracy <= 150) {
      return cached;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 6),
      ),
    );
  }

  @override
  Future<GatepassRequest> submitRequest(GatepassRequestDraft draft) async {
    final passType = switch (draft.type) {
      GatepassRequestType.localOuting ||
      GatepassRequestType.homeVisit => 'outpass',
      _ => 'leave_pass',
    };
    final response = await _authorizedRequest(
      (headers) => _client.post(
        _uri('/api/v1/operations/gatepass/requests'),
        headers: headers,
        body: jsonEncode({
          'passType': passType,
          'residency': passType == 'outpass' ? 'hosteller' : 'day_scholar',
          'destination': draft.destination,
          'reason': draft.reason,
          'guardianPhone': draft.guardianPhone,
          'departureAt': draft.departureAt.toUtc().toIso8601String(),
          'returnAt': draft.returnAt.toUtc().toIso8601String(),
        }),
      ),
      json: true,
    );
    return _request(_data(response), fallbackType: draft.type);
  }

  @override
  Future<GatepassRequest> cancelRequest(String requestId) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/v1/operations/gatepass/requests/$requestId'),
        headers: headers,
      ),
    );
    return _request(_data(response));
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
    if (json) 'content-type': 'application/json',
  };

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool json = false,
  }) async {
    var token = await _resolveAccessToken();
    var response = await send(_headers(token, json: json));
    if (response.statusCode == 401 && _accessTokenProvider != null) {
      token = await _resolveAccessToken(forceRefresh: true);
      response = await send(_headers(token, json: json));
    }
    return response;
  }

  Future<String> _resolveAccessToken({bool forceRefresh = false}) async {
    final provider = _accessTokenProvider;
    if (provider != null) return provider(forceRefresh: forceRefresh);
    return _accessToken!;
  }

  @override
  Future<VisitorInvitation> inviteVisitor(VisitorInvitationDraft draft) {
    throw const GatepassException(
      'Visitor invitations are not part of the Gatepass flow yet.',
    );
  }

  GatepassRequest _request(
    Map<String, dynamic> value, {
    GatepassRequestType? fallbackType,
  }) {
    final state = _text(value['state']);
    final status = switch (state) {
      'approved' => ApprovalStatus.approved,
      'rejected' => ApprovalStatus.rejected,
      'completed' => ApprovalStatus.completed,
      'cancelled' => ApprovalStatus.cancelled,
      _ => ApprovalStatus.pending,
    };
    return GatepassRequest(
      id: _text(value['id']),
      type:
          fallbackType ??
          ({'leave', 'leave_pass'}.contains(_text(value['passType']))
              ? GatepassRequestType.medical
              : GatepassRequestType.localOuting),
      departureAt: _date(value['departureAt']),
      returnAt: _date(value['returnAt']),
      destination: _text(value['destination']),
      reason: _text(value['reason']),
      guardianPhone: _text(value['guardianPhone']),
      status: status,
      submittedAt: _date(value['createdAt']),
      reviewNote: _text(value['decisionNote']).isEmpty
          ? null
          : _text(value['decisionNote']),
      qrPayload: _text(value['qrPayload']).isEmpty
          ? null
          : _text(value['qrPayload']),
      workflowState: state,
    );
  }

  GateMovement _movement(Map<String, dynamic> value) => GateMovement(
    id: _text(value['id']),
    direction: _text(value['direction']) == 'entry'
        ? MovementDirection.entry
        : MovementDirection.exit,
    recordedAt: _date(value['createdAt']),
    gate: _text(value['checkpoint'], fallback: 'Campus gate'),
    method: _text(value['method'], fallback: 'QR'),
  );

  /// What to say when a failure carries no readable body.
  ///
  /// 404 is the one worth naming: it means the server has no such route, which
  /// in practice means it is older than this app. "Try again" would be wrong
  /// advice — retrying a route that does not exist never starts working.
  String _statusMessage(int status) => switch (status) {
    404 =>
      'This server does not provide gatepass yet. It is running an older '
          'build of the API.',
    >= 500 => 'The gatepass service is failing right now. Try again shortly.',
    _ => 'The gatepass request failed ($status).',
  };

  Map<String, dynamic> _data(http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // A failure is allowed to arrive without a JSON body and still be
      // understood. Two of them do: the router answers 404 with nothing at all
      // when a build predates these endpoints, and the JSON extractor rejects a
      // malformed body with plain text. Reading the status first means those
      // say what happened instead of "unreadable".
      if (!ok) {
        throw GatepassUnavailableException(_statusMessage(response.statusCode));
      }
      throw const GatepassUnavailableException(
        'The gatepass service returned an unreadable response.',
      );
    }
    if (!ok) {
      // The API answers `{"error": "...", "code": "..."}` — a plain string.
      // An older shape nested the text under `error.message`, so both are read
      // rather than falling through to a sentence that says nothing.
      final error = body['error'];
      final message = switch (error) {
        final Map<String, dynamic> map => _text(map['message']),
        final String text => text,
        _ => '',
      };
      // Being outside the campus fence is the ordinary reason this refuses,
      // and "forbidden" would read to a learner as though they were barred.
      if (body['code'] == 'forbidden') {
        throw const OutsideCampusException(
          'You are outside the campus boundary, so today\'s entry QR cannot '
          'be activated yet. It will work once you are on campus.',
        );
      }
      throw GatepassException(
        message.isEmpty ? 'The gatepass request failed.' : message,
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const GatepassException('The gatepass response is missing data.');
    }
    return data;
  }
}

final _workflow = GatepassWorkflowDefinition(
  tenantId: 'active-tenant',
  version: 1,
  initialState: 'submitted',
  terminalStates: const ['approved', 'rejected', 'cancelled', 'completed'],
  states: const [
    GatepassWorkflowState(
      id: 'pending_parent',
      label: 'Parent approval',
      status: WorkflowStateStatus.pending,
    ),
    GatepassWorkflowState(
      id: 'pending_warden',
      label: 'Warden approval',
      status: WorkflowStateStatus.pending,
    ),
    GatepassWorkflowState(
      id: 'pending_advisor_or_hod',
      label: 'Advisor / HOD approval',
      status: WorkflowStateStatus.pending,
    ),
    GatepassWorkflowState(
      id: 'pending_principal',
      label: 'Principal approval',
      status: WorkflowStateStatus.pending,
    ),
    GatepassWorkflowState(
      id: 'approved',
      label: 'Approved',
      status: WorkflowStateStatus.approved,
    ),
    GatepassWorkflowState(
      id: 'rejected',
      label: 'Rejected',
      status: WorkflowStateStatus.rejected,
    ),
    GatepassWorkflowState(
      id: 'completed',
      label: 'Completed',
      status: WorkflowStateStatus.completed,
    ),
  ],
  transitions: const [],
);

Uri _normalizeBaseUri(String value) {
  final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Enter a valid API base URL.');
  }
  return uri;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : const [];
String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
double? _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
