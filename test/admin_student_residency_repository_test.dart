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
                  'departmentId': '11111111-1111-1111-1111-111111111111',
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

  test('loads and saves the primary parent WhatsApp details', () async {
    Map<String, dynamic>? savedBody;
    final repository = AdminStudentRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'student-1',
                  'name': 'Vishnu S',
                  'rollNo': '413225243049',
                  'department': 'AIDS',
                  'departmentId': '11111111-1111-1111-1111-111111111111',
                  'residency': 'day_scholar',
                  'mobileNumber': '9000000000',
                  'email': 'student@example.test',
                  'status': 'active',
                  'yearOfStudy': '2',
                  'section': 'A',
                  'sectionId': '22222222-2222-2222-2222-222222222222',
                  'guardianName': 'Parent Name',
                  'guardianPhone': '916382834651',
                  'guardianRelationship': 'Father',
                },
              ],
            }),
            200,
          );
        }
        savedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'student-1',
              'name': savedBody!['name'],
              'rollNo': savedBody!['rollNo'],
              'department': savedBody!['department'],
              'departmentId': savedBody!['departmentId'],
              'residency': savedBody!['residency'],
              'mobileNumber': savedBody!['mobileNumber'],
              'email': savedBody!['email'],
              'status': savedBody!['status'],
              'yearOfStudy': savedBody!['yearOfStudy'],
              'section': savedBody!['section'],
              'sectionId': savedBody!['sectionId'],
              'guardianName': savedBody!['guardianName'],
              'guardianPhone': savedBody!['guardianPhone'],
              'guardianRelationship': savedBody!['guardianRelationship'],
            },
          }),
          200,
        );
      }),
    );

    final student = (await repository.listStudents()).single;
    expect(student.guardianName, 'Parent Name');
    expect(student.guardianPhone, '916382834651');
    expect(student.guardianRelationship, 'Father');

    final updated = await repository.updateStudent(
      student.copyWith(
        guardianName: 'Updated Parent',
        guardianPhone: '919876543210',
        guardianRelationship: 'Mother',
      ),
    );

    expect(savedBody!['guardianName'], 'Updated Parent');
    expect(savedBody!['guardianPhone'], '919876543210');
    expect(savedBody!['guardianRelationship'], 'Mother');
    expect(savedBody!['departmentId'], '11111111-1111-1111-1111-111111111111');
    expect(savedBody!['sectionId'], '22222222-2222-2222-2222-222222222222');
    expect(updated.guardianName, 'Updated Parent');
  });
}
