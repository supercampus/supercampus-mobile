import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/approval_portal_repository.dart';

void main() {
  test('parent overview contains only linked child and actionable request', () async {
    final repository = BackendApprovalPortalRepository(
      baseUrl: 'https://api.supercampus.test',
      accessToken: 'parent-token',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer parent-token');
        return http.Response(
          jsonEncode({
            'data': {
              'viewerKind': 'parent',
              'children': [
                {
                  'userId': 'student-vishnu',
                  'name': 'Vishnu S',
                  'email': 'vsnu4education@gmail.com',
                  'rollNumber': 'MEC25AD48',
                  'department': 'Artificial Intelligence & Data Science',
                  'year': 'II',
                  'hostel': 'Boys Hostel',
                  'room': 'BH-204',
                },
              ],
              'requests': [
                {
                  'id': 'request-1',
                  'requesterUserId': 'student-vishnu',
                  'requesterName': 'Vishnu S',
                  'passType': 'outpass',
                  'destination': 'Home',
                  'reason': 'Family function',
                  'departureAt': '2026-09-01T10:00:00Z',
                  'returnAt': '2026-09-02T10:00:00Z',
                  'state': 'pending_parent',
                  'createdAt': '2026-08-31T10:00:00Z',
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    final store = await repository.load();

    expect(store.viewerKind, 'parent');
    expect(store.children.single.rollNumber, 'MEC25AD48');
    expect(store.requests.single.studentName, 'Vishnu S');
    expect(store.requests.single.canDecide('parent'), isTrue);
    expect(store.requests.single.canDecide('warden'), isFalse);
  });

  test('decision sends the selected outcome and note', () async {
    late Map<String, dynamic> body;
    final repository = BackendApprovalPortalRepository(
      baseUrl: 'https://api.supercampus.test',
      accessToken: 'warden-token',
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/operations/gatepass/requests/request-1/decision',
        );
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'data': {'state': 'rejected'}}), 200);
      }),
    );

    await repository.decide(
      requestId: 'request-1',
      approved: false,
      note: 'Return time is too late',
    );

    expect(body['decision'], 'rejected');
    expect(body['note'], 'Return time is too late');
  });
}

