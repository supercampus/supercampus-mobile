import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'hostel_models.dart';
import 'hostel_repository.dart';

class BackendHostelRepository implements HostelRepository {
  BackendHostelRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    required this.studentName,
    required this.studentCode,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;
  final String studentName;
  final String studentCode;

  @override
  Future<HostelStore> loadStore() async {
    final hostel = _data(
      await _request('GET', '/api/v1/operations/hostel/overview'),
    );
    Map<String, dynamic> gatepass = const {};
    try {
      gatepass = _data(
        await _request('GET', '/api/v1/operations/gatepass/overview'),
      );
    } catch (_) {
      // Hostel services remain useful even when gatepass is temporarily offline.
    }
    final student = _map(hostel['student']);
    final isHosteller = _text(student['residency']) == 'hosteller';
    final residency = isHosteller
        ? HostelResidency(
            id: _text(student['studentId'], fallback: _text(student['userId'])),
            studentId: _text(student['userId']),
            studentName: _text(student['name'], fallback: studentName),
            studentCode: _text(student['rollNumber'], fallback: studentCode),
            programme: _text(student['programme'], fallback: 'Student'),
            academicYear: _text(student['academicYear']),
            hostelName: _text(student['hostel'], fallback: 'Hostel'),
            blockName: _text(student['block']),
            floorNumber:
                int.tryParse(_text(student['floor'], fallback: '0')) ?? 0,
            roomNumber: _text(student['room'], fallback: 'Not assigned'),
            bedCode: _text(student['bed'], fallback: 'Bed not assigned'),
            checkInAt: DateTime.now(),
            residencyStatus: ResidencyStatus.active,
            presenceStatus: PresenceStatus.insideHostel,
            dueAmount: 0,
          )
        : null;
    final requests = _list(hostel['serviceRequests']);
    final outpasses = _list(gatepass['requests'])
        .where((row) => _text(row['passType']) == 'outpass')
        .map((row) => _outpass(row, residency))
        .toList(growable: false);
    final movements = _list(gatepass['movements'])
        .map(
          (row) => HostelMovement(
            id: _text(row['id']),
            residencyId: residency?.id ?? '',
            studentName: studentName,
            movementType: _text(row['direction']).toUpperCase(),
            timestamp: _date(row['createdAt']),
            gateName: _text(row['checkpoint'], fallback: 'Campus gate'),
            method: _text(row['method'], fallback: 'QR scan'),
            outpassId: _nullableText(row['requestId']),
          ),
        )
        .toList(growable: false);
    final entitlement = _map(hostel['feeEntitlement']);
    final settings = _map(hostel['diningSettings']);
    return HostelStore(
      activeResidency: residency,
      buildings: const [],
      applications: const [],
      outpasses: outpasses,
      movements: movements,
      messTokens: _list(
        hostel['mealTokens'],
      ).map((row) => _meal(row, residency)).toList(growable: false),
      complaints: requests
          .where((row) => _text(row['kind']) == 'complaint')
          .map((row) => _complaint(row, residency))
          .toList(growable: false),
      roomChangeRequests: requests
          .where((row) => _text(row['kind']) == 'room_change')
          .map((row) => _roomChange(row, residency))
          .toList(growable: false),
      visitorPasses: requests
          .where((row) => _text(row['kind']) == 'visitor')
          .map((row) => _visitor(row, residency))
          .toList(growable: false),
      clearance: _clearance(requests, residency),
      menuEnabled: settings['menuEnabled'] != false,
      messEnabled: settings['messEnabled'] != false,
      hostelFeeValidFrom: _nullableDate(entitlement['validFrom']),
      hostelFeeValidUntil: _nullableDate(entitlement['validUntil']),
    );
  }

  @override
  Future<HostelComplaint> submitComplaint({
    required String category,
    required String description,
  }) async {
    final row = _data(
      await _postRequest('complaint', {
        'category': category,
        'description': description,
      }),
    );
    return _complaint(row, null);
  }

  @override
  Future<RoomChangeRequest> requestRoomChange({
    required String reason,
    required String preferredHostel,
  }) async {
    final row = _data(
      await _postRequest('room_change', {
        'reason': reason,
        'preferredHostel': preferredHostel,
      }),
    );
    return _roomChange(row, null);
  }

  @override
  Future<VisitorPass> inviteVisitor({
    required String visitorName,
    required String visitorContact,
    required String purpose,
    required DateTime visitDate,
    required String validFromTime,
    required String validUntilTime,
  }) async {
    final row = _data(
      await _postRequest('visitor', {
        'visitorName': visitorName,
        'visitorContact': visitorContact,
        'purpose': purpose,
        'visitDate': _day(visitDate),
        'validFromTime': validFromTime,
        'validUntilTime': validUntilTime,
      }),
    );
    return _visitor(row, null);
  }

  @override
  Future<HostelClearance> submitVacateRequest() async {
    final row = _data(await _postRequest('clearance', const {}));
    return _clearance([row], null)!;
  }

  Future<Map<String, dynamic>> _postRequest(
    String kind,
    Map<String, dynamic> details,
  ) => _request('POST', '/api/v1/operations/hostel/requests', {
    'kind': kind,
    'details': details,
  });

  @override
  Future<HostelOutpass> requestOutpass({
    required DateTime leavingAt,
    required DateTime expectedReturnAt,
    required String destination,
    required String reason,
  }) async {
    final response =
        await _request('POST', '/api/v1/operations/gatepass/requests', {
          'passType': 'outpass',
          'residency': 'hosteller',
          'destination': destination,
          'reason': reason,
          'departureAt': leavingAt.toUtc().toIso8601String(),
          'returnAt': expectedReturnAt.toUtc().toIso8601String(),
        });
    return _outpass(_data(response), null);
  }

  @override
  Future<MessMealToken> redeemMessMeal(String tokenId) async {
    throw const HostelException(
      'Meal tokens can only be redeemed by the authorised mess scanner.',
    );
  }

  @override
  Future<HostelApplication> applyForAccommodation({
    required String preferredRoomType,
    required String specialRequirements,
  }) async => throw const HostelException(
    'Accommodation applications are not enabled for this campus yet.',
  );

  @override
  Future<HostelOutpass> approveOutpass(String outpassId) async =>
      throw const HostelException('Use the warden approval queue.');

  @override
  Future<HostelMovement> scanOutpassGate({
    required String outpassId,
    required String gateName,
    required String action,
  }) async => throw const HostelException('Use the security QR scanner.');

  @override
  Future<HostelClearance> updateClearanceChecklist({
    required String clearanceId,
    required bool roomCleared,
    required bool assetsReturned,
    required bool keyReturned,
    required bool feesPaid,
    required bool messCleared,
    required bool complaintsClosed,
    required bool damageSettled,
  }) async =>
      throw const HostelException('Only hostel staff can update clearance.');

  @override
  Future<HostelResidency> completeCheckout(String residencyId) async =>
      throw const HostelException('Only hostel staff can complete checkout.');

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    var token = await _accessTokenProvider();
    Future<http.Response> send(String value) {
      final headers = {
        'authorization': 'Bearer $value',
        'x-client-surface': 'app',
        'accept': 'application/json',
        if (body != null) 'content-type': 'application/json',
      };
      return method == 'GET'
          ? _client.get(_baseUri.resolve(path), headers: headers)
          : _client.post(
              _baseUri.resolve(path),
              headers: headers,
              body: jsonEncode(body),
            );
    }

    var response = await send(token);
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await send(token);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      final error = decoded is Map ? decoded['error'] : null;
      final message = error is Map ? error['message'] : error;
      throw HostelException(
        message?.toString() ??
            'Hostel service failed (${response.statusCode}).',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  HostelOutpass _outpass(
    Map<String, dynamic> row,
    HostelResidency? residency,
  ) => HostelOutpass(
    id: _text(row['id']),
    residencyId: residency?.id ?? '',
    studentName: studentName,
    studentCode: studentCode,
    hostelRoom:
        '${residency?.hostelName ?? 'Hostel'} · ${residency?.roomNumber ?? ''}',
    leavingAt: _date(row['departureAt']),
    expectedReturnAt: _date(row['returnAt']),
    destination: _text(row['destination']),
    reason: _text(row['reason']),
    status: _outpassStatus(_text(row['state'])),
    qrPayload: _nullableText(row['qrPayload']),
  );

  MessMealToken _meal(Map<String, dynamic> row, HostelResidency? residency) =>
      MessMealToken(
        id: _text(row['id']),
        residencyId: residency?.id ?? '',
        studentName: studentName,
        mealType: MealType.values.firstWhere(
          (value) => value.name == _text(row['mealType']),
          orElse: () => MealType.breakfast,
        ),
        date: _date(row['serviceDate']),
        status: MealTokenStatus.values.firstWhere(
          (value) => value.name == _text(row['status']),
          orElse: () => MealTokenStatus.expired,
        ),
        qrCode: _text(row['qrPayload']),
        redeemedAt: _nullableDate(row['redeemedAt']),
      );

  HostelComplaint _complaint(
    Map<String, dynamic> row,
    HostelResidency? residency,
  ) {
    final details = _map(row['details']);
    return HostelComplaint(
      id: _shortId(row['id'], 'HM'),
      residencyId: residency?.id ?? '',
      roomNumber: residency?.roomNumber ?? _text(details['room']),
      category: _text(details['category'], fallback: 'General'),
      description: _text(details['description']),
      status: _complaintStatus(_text(row['status'])),
      createdAt: _date(row['createdAt']),
      assignedTo: _nullableText(details['assignedTo']),
      resolutionNotes: _nullableText(details['resolutionNotes']),
    );
  }

  RoomChangeRequest _roomChange(
    Map<String, dynamic> row,
    HostelResidency? residency,
  ) {
    final details = _map(row['details']);
    return RoomChangeRequest(
      id: _shortId(row['id'], 'RCR'),
      residencyId: residency?.id ?? '',
      studentName: studentName,
      currentRoom: residency == null
          ? _text(details['currentRoom'])
          : '${residency.hostelName} / ${residency.roomNumber} / ${residency.bedCode}',
      reason: _text(details['reason']),
      preferredHostel: _text(details['preferredHostel']),
      status: _roomStatus(_text(row['status'])),
      requestedAt: _date(row['createdAt']),
      newRoomAllocated: _nullableText(details['newRoomAllocated']),
    );
  }

  VisitorPass _visitor(Map<String, dynamic> row, HostelResidency? residency) {
    final details = _map(row['details']);
    return VisitorPass(
      id: _shortId(row['id'], 'VIS'),
      residencyId: residency?.id ?? '',
      visitorName: _text(details['visitorName']),
      visitorContact: _text(details['visitorContact']),
      purpose: _text(details['purpose']),
      visitDate: _date(details['visitDate']),
      validFromTime: _text(details['validFromTime']),
      validUntilTime: _text(details['validUntilTime']),
      status: _text(row['status']).toUpperCase(),
    );
  }

  HostelClearance? _clearance(
    List<Map<String, dynamic>> rows,
    HostelResidency? residency,
  ) {
    final matches = rows.where((row) => _text(row['kind']) == 'clearance');
    if (matches.isEmpty) return null;
    final row = matches.first;
    final details = _map(row['details']);
    return HostelClearance(
      id: _shortId(row['id'], 'CLR'),
      residencyId: residency?.id ?? '',
      studentName: studentName,
      roomNumber: residency?.roomNumber ?? '',
      roomCleared: details['roomCleared'] == true,
      assetsReturned: details['assetsReturned'] == true,
      keyReturned: details['keyReturned'] == true,
      feesPaid: details['feesPaid'] == true,
      messCleared: details['messCleared'] == true,
      complaintsClosed: details['complaintsClosed'] == true,
      damageSettled: details['damageSettled'] == true,
      status: ClearanceStatus.values.firstWhere(
        (value) => value.name == _text(row['status']),
        orElse: () => ClearanceStatus.requested,
      ),
    );
  }
}

class HostelException implements Exception {
  const HostelException(this.message);
  final String message;
  @override
  String toString() => message;
}

Map<String, dynamic> _data(Map<String, dynamic> response) =>
    _map(response['data']);
Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
    : <Map<String, dynamic>>[];
String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}

DateTime _date(Object? value) =>
    DateTime.tryParse(_text(value)) ?? DateTime.now();
DateTime? _nullableDate(Object? value) => DateTime.tryParse(_text(value));
String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _shortId(Object? value, String prefix) {
  final id = _text(value).replaceAll('-', '').toUpperCase();
  return '$prefix-${id.length > 6 ? id.substring(0, 6) : id}';
}

OutpassStatus _outpassStatus(String value) => switch (value) {
  'approved' => OutpassStatus.approved,
  'active' => OutpassStatus.active,
  'completed' => OutpassStatus.completed,
  'rejected' => OutpassStatus.rejected,
  'expired' => OutpassStatus.expired,
  'pending_warden' || 'pending_parent' => OutpassStatus.underReview,
  _ => OutpassStatus.submitted,
};
ComplaintStatus _complaintStatus(String value) => switch (value) {
  'assigned' => ComplaintStatus.assigned,
  'in_progress' => ComplaintStatus.inProgress,
  'resolved' => ComplaintStatus.resolved,
  'closed' => ComplaintStatus.closed,
  _ => ComplaintStatus.submitted,
};
RoomChangeStatus _roomStatus(String value) => switch (value) {
  'under_review' => RoomChangeStatus.underReview,
  'approved' => RoomChangeStatus.approved,
  'new_room_reserved' => RoomChangeStatus.newRoomReserved,
  'moving' => RoomChangeStatus.moving,
  'completed' => RoomChangeStatus.completed,
  'rejected' => RoomChangeStatus.rejected,
  'cancelled' => RoomChangeStatus.cancelled,
  _ => RoomChangeStatus.submitted,
};
