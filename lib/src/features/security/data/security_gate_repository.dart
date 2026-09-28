import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

enum GateDirection { entry, exit }

extension GateDirectionLabel on GateDirection {
  String get apiValue => name;
  String get label => this == GateDirection.entry ? 'Gate in' : 'Gate out';
}

GateDirection _direction(dynamic value) =>
    value == 'exit' ? GateDirection.exit : GateDirection.entry;

/// Human label for a backend pass type.
String gatePassTypeLabel(String? value) => switch (value) {
  'daily_access' => 'Campus entry',
  'leave_pass' => 'Leave pass',
  'outpass' => 'Outpass',
  'visitor' => 'Visitor pass',
  'walk_in' => 'Walk-in visitor',
  null || '' => 'Gate pass',
  final other => other,
};

/// One recorded gate-in or gate-out, as the movement log returns it.
class SecurityGateMovement {
  const SecurityGateMovement({
    required this.id,
    required this.userId,
    required this.direction,
    required this.checkpoint,
    required this.createdAt,
    this.requestId,
    this.visitorPassId,
    this.holderName,
    this.passType,
    this.validUntil,
    this.rollNumber,
    this.photoUrl,
    this.method,
    this.scannedByName,
    this.late = false,
  });

  factory SecurityGateMovement.fromJson(Map<String, dynamic> value) {
    return SecurityGateMovement(
      id: _text(value['id']),
      userId: _text(value['userId'], fallback: 'Campus visitor'),
      requestId: _nullableText(value['requestId']),
      visitorPassId: _nullableText(value['visitorPassId']),
      holderName: _nullableText(value['holderName']),
      passType: _nullableText(value['passType']),
      validUntil: _date(value['validUntil']),
      rollNumber: _nullableText(value['rollNumber']),
      photoUrl: _nullableText(value['photoUrl']),
      method: _nullableText(value['method']),
      scannedByName: _nullableText(value['scannedByName']),
      late: value['late'] == true,
      direction: _direction(value['direction']),
      checkpoint: _text(value['checkpoint'], fallback: 'Main gate'),
      createdAt: _date(value['createdAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String? requestId;
  final String? visitorPassId;
  final GateDirection direction;
  final String checkpoint;
  final DateTime createdAt;
  final String? holderName;
  final String? passType;
  final DateTime? validUntil;
  final String? rollNumber;
  final String? photoUrl;
  final String? method;
  final String? scannedByName;

  /// A return recorded after the pass window closed.
  final bool late;

  String get passTypeLabel => gatePassTypeLabel(passType);
  String get displayName => holderName ?? 'Unknown holder';
}

/// A visitor currently inside campus (gated in, not yet out).
class VisitorOnCampus {
  const VisitorOnCampus({
    required this.id,
    required this.name,
    required this.hostName,
    required this.purpose,
    required this.walkIn,
    this.phone,
    this.vehicleNumber,
    this.checkedInAt,
  });

  factory VisitorOnCampus.fromJson(Map<String, dynamic> value) =>
      VisitorOnCampus(
        id: _text(value['id']),
        name: _text(value['visitorName'], fallback: 'Visitor'),
        hostName: _text(value['hostName']),
        purpose: _text(value['purpose']),
        walkIn: value['entryMode'] == 'walk_in',
        phone: _nullableText(value['visitorPhone']),
        vehicleNumber: _nullableText(value['vehicleNumber']),
        checkedInAt: _date(value['checkedInAt']),
      );

  final String id;
  final String name;
  final String hostName;
  final String purpose;
  final bool walkIn;
  final String? phone;
  final String? vehicleNumber;
  final DateTime? checkedInAt;
}

/// What the gate desk shows: recent movements, today's counts, and the
/// visitors still inside.
class GateActivity {
  const GateActivity({
    this.movements = const [],
    this.entriesToday = 0,
    this.exitsToday = 0,
    this.visitorsOnCampus = const [],
  });

  final List<SecurityGateMovement> movements;
  final int entriesToday;
  final int exitsToday;
  final List<VisitorOnCampus> visitorsOnCampus;
}

class GateMovementPerson {
  const GateMovementPerson({
    required this.name,
    this.rollNumber,
    this.email,
    this.department,
    this.phone,
    this.photoUrl,
  });

  final String name;
  final String? rollNumber;
  final String? email;
  final String? department;
  final String? phone;
  final String? photoUrl;
}

class GateMovementPass {
  const GateMovementPass({
    required this.type,
    this.state,
    this.destination,
    this.reason,
    this.purpose,
    this.hostName,
    this.vehicleNumber,
    this.idNote,
    this.validFrom,
    this.validUntil,
    this.approvedBy,
    this.registeredBy,
  });

  final String type;
  final String? state;
  final String? destination;
  final String? reason;
  final String? purpose;
  final String? hostName;
  final String? vehicleNumber;
  final String? idNote;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String? approvedBy;
  final String? registeredBy;

  String get typeLabel => gatePassTypeLabel(type);
}

class GateMovementDetail {
  const GateMovementDetail({
    required this.movement,
    required this.person,
    this.pass,
    this.timeline = const [],
  });

  factory GateMovementDetail.fromJson(Map<String, dynamic> value) {
    final movement = SecurityGateMovement.fromJson(value);
    final person = value['person'] is Map<String, dynamic>
        ? value['person'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final pass = value['pass'] is Map<String, dynamic>
        ? value['pass'] as Map<String, dynamic>
        : null;
    final timeline = value['timeline'] is List
        ? (value['timeline'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SecurityGateMovement.fromJson)
              .toList(growable: false)
        : const <SecurityGateMovement>[];
    return GateMovementDetail(
      movement: movement,
      person: GateMovementPerson(
        name: _text(person['name'], fallback: movement.displayName),
        rollNumber: _nullableText(person['rollNumber']),
        email: _nullableText(person['email']),
        department: _nullableText(person['department']),
        phone: _nullableText(person['phone']),
        photoUrl: _nullableText(person['photoUrl']),
      ),
      pass: pass == null
          ? null
          : GateMovementPass(
              type: _text(pass['type'], fallback: movement.passType ?? ''),
              state: _nullableText(pass['state']),
              destination: _nullableText(pass['destination']),
              reason: _nullableText(pass['reason']),
              purpose: _nullableText(pass['purpose']),
              hostName: _nullableText(pass['hostName']),
              vehicleNumber: _nullableText(pass['vehicleNumber']),
              idNote: _nullableText(pass['idNote']),
              validFrom: _date(pass['validFrom']),
              validUntil: _date(pass['validUntil']),
              approvedBy: _nullableText(pass['approvedBy']),
              registeredBy: _nullableText(pass['registeredBy']),
            ),
      timeline: timeline,
    );
  }

  final SecurityGateMovement movement;
  final GateMovementPerson person;
  final GateMovementPass? pass;
  final List<SecurityGateMovement> timeline;
}

/// A new walk-in visitor, as the guard enters it at the gate.
class WalkInVisitorDraft {
  const WalkInVisitorDraft({
    required this.name,
    required this.phone,
    required this.purpose,
    required this.hostName,
    required this.checkpoint,
    this.idNote,
    this.vehicleNumber,
  });

  final String name;
  final String phone;
  final String purpose;
  final String hostName;
  final String checkpoint;
  final String? idNote;
  final String? vehicleNumber;

  Map<String, dynamic> toJson() => {
    'visitorName': name.trim(),
    'visitorPhone': phone.trim(),
    'purpose': purpose.trim(),
    'hostName': hostName.trim(),
    'checkpoint': checkpoint.trim(),
    if (idNote != null && idNote!.trim().isNotEmpty) 'idNote': idNote!.trim(),
    if (vehicleNumber != null && vehicleNumber!.trim().isNotEmpty)
      'vehicleNumber': vehicleNumber!.trim(),
  };
}

/// Field checks shared by the walk-in form; they mirror the server's.
abstract final class WalkInValidation {
  static String? name(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 2) return 'Enter the visitor’s full name';
    if (text.length > 80) return 'Keep the name under 80 characters';
    return null;
  }

  static String? phone(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^[0-9 +()\-]*$').hasMatch(text)) {
      return 'Use digits only';
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a 10 to 15 digit phone number';
    }
    return null;
  }

  static String? purpose(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter the purpose of the visit';
    if (text.length > 200) return 'Keep the purpose under 200 characters';
    return null;
  }

  static String? host(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter whom the visitor is meeting';
    if (text.length > 120) return 'Keep this under 120 characters';
    return null;
  }

  static String? idNote(String? value) {
    if ((value ?? '').trim().length > 120) {
      return 'Keep the ID note under 120 characters';
    }
    return null;
  }

  static String? vehicle(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (text.length > 16 || !RegExp(r'^[A-Za-z0-9 \-]+$').hasMatch(text)) {
      return 'Enter a valid vehicle number';
    }
    return null;
  }
}

abstract interface class SecurityGateRepository {
  /// Recent movements (newest first), today's counts and visitors inside.
  /// Pass [before] to page further back through the log.
  Future<GateActivity> activity({DateTime? before});

  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  });

  Future<GateMovementDetail> movementDetail(String movementId);

  Future<SecurityGateMovement> registerWalkIn(WalkInVisitorDraft draft);

  Future<SecurityGateMovement> visitorGateOut({
    required String visitorPassId,
    required String checkpoint,
  });
}

class SecurityGateException implements Exception {
  const SecurityGateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The pass was already used for this movement. [previous] is the movement
/// that used it: when, at which checkpoint, and by whom.
class GateAlreadyScannedException extends SecurityGateException {
  const GateAlreadyScannedException(super.message, {this.previous});

  final SecurityGateMovement? previous;
}

class BackendSecurityGateRepository implements SecurityGateRepository {
  BackendSecurityGateRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = _normalizeBaseUri(baseUrl),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  static const _root = '/api/v1/operations/gatepass';

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = _baseUri.resolve(path);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  @override
  Future<GateActivity> activity({DateTime? before}) async {
    final response = await _authorizedRequest(
      (headers) => _client.get(
        _uri('$_root/movements', {
          'limit': '50',
          if (before != null) 'before': before.toUtc().toIso8601String(),
        }),
        headers: headers,
      ),
    );
    final data = _data(response);
    final today = data['today'] is Map<String, dynamic>
        ? data['today'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return GateActivity(
      movements: _list(data['movements'], SecurityGateMovement.fromJson),
      entriesToday: _int(today['entries']),
      exitsToday: _int(today['exits']),
      visitorsOnCampus: _list(
        data['visitorsOnCampus'],
        VisitorOnCampus.fromJson,
      ),
    );
  }

  @override
  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  }) async {
    final code = qrPayload.trim();
    if (code.isEmpty) {
      throw const SecurityGateException('Scan a gatepass QR first.');
    }
    validateGatepassMovementDirection(qrPayload: code, direction: direction);
    final response = await _authorizedRequest(
      (headers) => _client.post(
        _uri('$_root/scan'),
        headers: headers,
        body: jsonEncode({
          'qrPayload': code,
          'direction': direction.apiValue,
          'checkpoint': checkpoint.trim(),
        }),
      ),
      json: true,
    );
    return SecurityGateMovement.fromJson(_data(response));
  }

  @override
  Future<GateMovementDetail> movementDetail(String movementId) async {
    final response = await _authorizedRequest(
      (headers) => _client.get(
        _uri('$_root/movements/${Uri.encodeComponent(movementId)}'),
        headers: headers,
      ),
    );
    return GateMovementDetail.fromJson(_data(response));
  }

  @override
  Future<SecurityGateMovement> registerWalkIn(WalkInVisitorDraft draft) async {
    final response = await _authorizedRequest(
      (headers) => _client.post(
        _uri('$_root/visitors/walk-in'),
        headers: headers,
        body: jsonEncode(draft.toJson()),
      ),
      json: true,
    );
    return SecurityGateMovement.fromJson(_data(response));
  }

  @override
  Future<SecurityGateMovement> visitorGateOut({
    required String visitorPassId,
    required String checkpoint,
  }) async {
    final response = await _authorizedRequest(
      (headers) => _client.post(
        _uri('$_root/visitors/${Uri.encodeComponent(visitorPassId)}/gate-out'),
        headers: headers,
        body: jsonEncode({'checkpoint': checkpoint.trim()}),
      ),
      json: true,
    );
    return SecurityGateMovement.fromJson(_data(response));
  }

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool json = false,
  }) async {
    var token = await _accessTokenProvider();
    var response = await send(_headers(token, json: json));
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await send(_headers(token, json: json));
    }
    return response;
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
    if (json) 'content-type': 'application/json',
  };

  Map<String, dynamic> _data(http.Response response) {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw gateErrorFromResponse(response.statusCode, body);
    }
    final data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw const SecurityGateException(
        'The gatepass service returned an incomplete response.',
      );
    }
    return data;
  }
}

/// Maps an error response to the exception the portal shows. A 409 with code
/// `already_scanned` becomes [GateAlreadyScannedException].
SecurityGateException gateErrorFromResponse(
  int statusCode,
  Map<String, dynamic>? body,
) {
  final error = body?['error'];
  final serverMessage = switch (error) {
    final String value => value,
    final Map<String, dynamic> value => _text(value['message']),
    _ => '',
  };
  if (statusCode == 409 && body?['code'] == 'already_scanned') {
    final details = body?['details'];
    return GateAlreadyScannedException(
      serverMessage.trim().isEmpty ? 'Already scanned' : serverMessage,
      previous: details is Map<String, dynamic>
          ? SecurityGateMovement.fromJson(details)
          : null,
    );
  }
  final fallback = switch (statusCode) {
    403 => 'This account does not have gate-scanner access.',
    404 => 'This QR is invalid, expired, or already unavailable.',
    409 => 'This gate movement conflicts with the current pass state.',
    >= 500 => 'The gatepass service is temporarily unavailable.',
    _ => 'The gatepass request failed ($statusCode).',
  };
  return SecurityGateException(
    serverMessage.trim().isEmpty ? fallback : serverMessage,
  );
}

/// Offline stand-in for mock builds. It enforces the same one-time rules the
/// server does, so the mock portal behaves like the real one.
class MockSecurityGateRepository implements SecurityGateRepository {
  final List<SecurityGateMovement> _movements = [];
  final List<VisitorOnCampus> _visitors = [];
  final Map<String, WalkInVisitorDraft> _drafts = {};
  var _sequence = 0;

  String _nextId(String prefix) => '$prefix-${++_sequence}';

  bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  @override
  Future<GateActivity> activity({DateTime? before}) async {
    final today = _movements.where((item) => _isToday(item.createdAt));
    final entries = today
        .where((item) => item.direction == GateDirection.entry)
        .length;
    return GateActivity(
      movements: List.unmodifiable(
        before == null
            ? _movements
            : _movements.where((item) => item.createdAt.isBefore(before)),
      ),
      entriesToday: entries,
      exitsToday: today.length - entries,
      visitorsOnCampus: List.unmodifiable(_visitors),
    );
  }

  @override
  Future<SecurityGateMovement> scan({
    required String qrPayload,
    required GateDirection direction,
    required String checkpoint,
  }) async {
    final code = qrPayload.trim();
    if (code.isEmpty) {
      throw const SecurityGateException('Scan a gatepass QR first.');
    }
    validateGatepassMovementDirection(qrPayload: code, direction: direction);
    final previous = _movements.where(
      (item) => item.requestId == code && item.direction == direction,
    );
    if (previous.isNotEmpty) {
      final first = previous.first;
      throw GateAlreadyScannedException(
        'Already scanned at ${first.createdAt.hour}:${first.createdAt.minute.toString().padLeft(2, '0')} by ${first.checkpoint}',
        previous: first,
      );
    }
    final isOutpass = code.contains('outpass') || code.contains('leave');
    final movement = SecurityGateMovement(
      id: _nextId('scan'),
      userId: '413225243049',
      requestId: code,
      holderName: 'Alex Johnson',
      passType: direction == GateDirection.entry
          ? 'Daily Gate-In Pass'
          : (isOutpass ? 'Approved Outpass' : 'Approved Leave Pass'),
      direction: direction,
      checkpoint: checkpoint,
      scannedByName: 'Gate security',
      createdAt: DateTime.now(),
    );
    _movements.insert(0, movement);
    return movement;
  }

  @override
  Future<GateMovementDetail> movementDetail(String movementId) async {
    final movement = _movements.firstWhere(
      (item) => item.id == movementId,
      orElse: () => throw const SecurityGateException('Movement not found.'),
    );
    final draft = _drafts[movement.visitorPassId];
    return GateMovementDetail(
      movement: movement,
      person: GateMovementPerson(
        name: movement.displayName,
        phone: draft?.phone,
      ),
      pass: GateMovementPass(
        type: movement.passType ?? '',
        purpose: draft?.purpose,
        hostName: draft?.hostName,
        vehicleNumber: draft?.vehicleNumber,
        idNote: draft?.idNote,
      ),
      timeline: [movement],
    );
  }

  @override
  Future<SecurityGateMovement> registerWalkIn(WalkInVisitorDraft draft) async {
    final passId = _nextId('visitor');
    _drafts[passId] = draft;
    final now = DateTime.now();
    _visitors.insert(
      0,
      VisitorOnCampus(
        id: passId,
        name: draft.name.trim(),
        hostName: draft.hostName.trim(),
        purpose: draft.purpose.trim(),
        walkIn: true,
        phone: draft.phone.trim(),
        vehicleNumber: draft.vehicleNumber,
        checkedInAt: now,
      ),
    );
    final movement = SecurityGateMovement(
      id: _nextId('scan'),
      userId: passId,
      visitorPassId: passId,
      holderName: draft.name.trim(),
      passType: 'walk_in',
      method: 'walk_in',
      direction: GateDirection.entry,
      checkpoint: draft.checkpoint,
      createdAt: now,
    );
    _movements.insert(0, movement);
    return movement;
  }

  @override
  Future<SecurityGateMovement> visitorGateOut({
    required String visitorPassId,
    required String checkpoint,
  }) async {
    final index = _visitors.indexWhere((item) => item.id == visitorPassId);
    if (index < 0) {
      final previous = _movements.where(
        (item) =>
            item.visitorPassId == visitorPassId &&
            item.direction == GateDirection.exit,
      );
      throw GateAlreadyScannedException(
        'Already scanned',
        previous: previous.isEmpty ? null : previous.first,
      );
    }
    final visitor = _visitors.removeAt(index);
    final movement = SecurityGateMovement(
      id: _nextId('scan'),
      userId: visitorPassId,
      visitorPassId: visitorPassId,
      holderName: visitor.name,
      passType: visitor.walkIn ? 'walk_in' : 'visitor',
      method: 'manual',
      direction: GateDirection.exit,
      checkpoint: checkpoint,
      createdAt: DateTime.now(),
    );
    _movements.insert(0, movement);
    return movement;
  }
}

/// Validates that a gatepass QR code matches the intended movement direction.
/// Gate-In passes cannot be used to exit campus.
/// Gate-Out passes (Outpasses/Leave passes) cannot be used to enter campus.
void validateGatepassMovementDirection({
  required String qrPayload,
  required GateDirection direction,
}) {
  final code = qrPayload.trim().toLowerCase();
  if (code.isEmpty) {
    throw const SecurityGateException('Scan a gatepass QR first.');
  }

  // Gate-In signatures: daily pass, campus entry, student roll admission
  final isGateIn =
      code.contains('/day/') ||
      code.contains('/entry/') ||
      code.contains('/gate_in/') ||
      code.contains('gate-in') ||
      code.contains('campus_entry');

  // Gate-Out signatures: outpass, leave pass, campus exit
  final isGateOut =
      code.contains('/outpass/') ||
      code.contains('/leave/') ||
      code.contains('/exit/') ||
      code.startsWith('sc-outpass:') ||
      code.startsWith('mec-gp-');

  if (direction == GateDirection.entry && isGateOut && !isGateIn) {
    throw const SecurityGateException(
      'Invalid pass: This is an Outpass/Leave pass (Gate-Out). It cannot be used for campus Gate-In.',
    );
  }

  if (direction == GateDirection.exit && isGateIn && !isGateOut) {
    throw const SecurityGateException(
      'Invalid pass: This is a Gate-In pass. Campus exit (Gate-Out) requires an approved Outpass or Leave pass.',
    );
  }
}

Uri _normalizeBaseUri(String value) {
  final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Enter a valid API base URL.');
  }
  return uri;
}

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) return const [];
  return value
      .whereType<Map<String, dynamic>>()
      .map(parse)
      .toList(growable: false);
}

int _int(dynamic value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  final String v => int.tryParse(v) ?? 0,
  _ => 0,
};

DateTime? _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();

String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
String? _nullableText(dynamic value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}
