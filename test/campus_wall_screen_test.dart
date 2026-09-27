import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/library/data/librarian_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/campus_wall_screen.dart';

LibrarianRepository repositoryReturning(int status, Object body) =>
    LibrarianRepository(
      baseUrl: 'https://api.example.test',
      accessToken: 'token',
      client: MockClient(
        (_) async => http.Response(
          body is String ? body : jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

Future<void> pumpWall(WidgetTester tester, LibrarianRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CampusWallScreen(announcementRepository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, Object?> announcement(String id, String title) => {
  'id': id,
  'announcementType': 'Circular',
  'announcementDate': '2026-09-27',
  'title': title,
  'message': 'Details',
  'status': 'approved',
  'createdByName': 'admin@mec.local',
  'createdAt': '2026-09-27T10:00:00Z',
};

const wallErrorTitle = 'Announcements didn\u2019t load';

void main() {
  testWidgets('a refused request shows the server reason and status', (
    tester,
  ) async {
    await pumpWall(
      tester,
      repositoryReturning(403, {
        'error': {'message': 'This session cannot access the requested tenant or resource'},
      }),
    );
    expect(find.text(wallErrorTitle), findsOneWidget);
    expect(
      find.text(
        'This session cannot access the requested tenant or resource (HTTP 403)',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a proxy error page is reported with its status', (tester) async {
    await pumpWall(tester, repositoryReturning(502, '<html>Bad gateway</html>'));
    expect(
      find.text('The server returned an unexpected response (HTTP 502).'),
      findsOneWidget,
    );
  });

  testWidgets('one unreadable announcement does not hide the others', (
    tester,
  ) async {
    await pumpWall(
      tester,
      repositoryReturning(200, {
        'data': {
          'announcements': [
            announcement('a1', 'Library closed on Monday'),
            // announcementType of the wrong type makes this row unreadable.
            {...announcement('a2', 'Broken'), 'announcementType': 42},
          ],
        },
      }),
    );
    expect(find.text('Library closed on Monday'), findsOneWidget);
    expect(find.text(wallErrorTitle), findsNothing);
  });
}
