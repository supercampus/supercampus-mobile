import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/app_version.dart';

void main() {
  test('About shows the version declared in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([^\s+]+)\+(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(appVersionName, match!.group(1));
    expect(appBuildNumber, match.group(2));
  });
}
