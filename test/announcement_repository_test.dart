import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/library/data/librarian_repository.dart';

void main() {
  test(
    'reads approved tenant announcements with their image metadata',
    () async {
      final repository = LibrarianRepository(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/operations/library/announcements');
          expect(request.headers['authorization'], 'Bearer token');
          return http.Response(
            jsonEncode({
              'data': {
                'announcements': [
                  {
                    'id': 'announcement-1',
                    'announcementType': 'Campus event',
                    'announcementDate': '2026-09-15',
                    'title': 'Innovation Day registrations',
                    'message': 'Reserve a presentation slot.',
                    'status': 'approved',
                    'createdByName': 'Campus Admin',
                    'createdAt': '2026-09-11T08:00:00Z',
                    'attachmentName': 'innovation-day.webp',
                    'attachmentUrl':
                        'https://cdn.example.test/innovation-day.webp',
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final announcements = await repository.announcements();

      expect(announcements, hasLength(1));
      expect(announcements.single.status, 'approved');
      expect(announcements.single.attachmentName, 'innovation-day.webp');
      expect(
        announcements.single.attachmentUrl,
        'https://cdn.example.test/innovation-day.webp',
      );
    },
  );

  test('publishes image metadata with the announcement', () async {
    final repository = LibrarianRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['attachmentName'], 'campus-event.png');
        expect(body['attachmentUrl'], 'https://cdn.example.test/event.png');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'announcement-2',
              'announcementType': body['announcementType'],
              'announcementDate': body['announcementDate'],
              'title': body['title'],
              'message': body['message'],
              'status': 'approved',
              'createdByName': 'Campus Admin',
              'createdAt': '2026-09-11T08:00:00Z',
              'attachmentName': body['attachmentName'],
              'attachmentUrl': body['attachmentUrl'],
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final saved = await repository.createAnnouncement(
      type: 'Campus event',
      announcementDate: DateTime(2026, 9, 15),
      title: 'Innovation Day registrations',
      message: 'Reserve a presentation slot.',
      attachmentName: 'campus-event.png',
      attachmentUrl: 'https://cdn.example.test/event.png',
    );

    expect(saved.status, 'approved');
    expect(saved.attachmentUrl, 'https://cdn.example.test/event.png');
  });

  test('publishes a circular with PDF attachment', () async {
    final repository = LibrarianRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['announcementType'], 'Circular');
        expect(body['attachmentName'], 'exam-circular.pdf');
        expect(body['attachmentUrl'], 'https://cdn.example.test/exam-circular.pdf');
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'announcement-circular-1',
              'announcementType': body['announcementType'],
              'announcementDate': body['announcementDate'],
              'title': body['title'],
              'message': body['message'],
              'status': 'approved',
              'createdByName': 'Campus Admin',
              'createdAt': '2026-09-24T08:00:00Z',
              'attachmentName': body['attachmentName'],
              'attachmentUrl': body['attachmentUrl'],
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final saved = await repository.createAnnouncement(
      type: 'Circular',
      announcementDate: DateTime(2026, 9, 24),
      title: 'Mid-term Exam Circular',
      message: 'Official circular regarding semester exams schedule and guidelines.',
      attachmentName: 'exam-circular.pdf',
      attachmentUrl: 'https://cdn.example.test/exam-circular.pdf',
    );

    expect(saved.type, 'Circular');
    expect(saved.attachmentName, 'exam-circular.pdf');
    expect(saved.attachmentUrl, 'https://cdn.example.test/exam-circular.pdf');
    expect(saved.status, 'approved');
  });

  test('surfaces actual backend error message on failure', () async {
    final repository = LibrarianRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'Enter an announcement type, date, title and description',
            'code': 'bad_request',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => repository.createAnnouncement(
        type: 'Circular',
        announcementDate: DateTime(2026, 9, 24),
        title: '',
        message: '',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Enter an announcement type, date, title and description',
        ),
      ),
    );
  });
}

