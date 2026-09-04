import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_student_repository.dart';

void main() {
  test('loads and updates the canonical student residency', () async {
    final requests = <http.Request>[];
    final repository = AdminStudentRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'student-1',
                  'name': 'Vishnu S',
                  'rollNo': '413225243049',
                  'department': 'AIDS',
                  'residency': 'day_scholar',
                },
              ],
            }),
            200,
          );
        }
        expect(jsonDecode(request.body), {'residency': 'hosteller'});
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'student-1',
              'name': 'Vishnu S',
              'residency': 'hosteller',
            },
          }),
          200,
        );
      }),
    );

    final students = await repository.listStudents();
    expect(students.single.residency, ManagedStudentResidency.dayScholar);

    final updated = await repository.setResidency(
      'student-1',
      ManagedStudentResidency.hosteller,
    );
    expect(updated, ManagedStudentResidency.hosteller);
    expect(
      requests.last.url.path,
      '/api/v1/student-master/student-1/residency',
    );
  });
}
