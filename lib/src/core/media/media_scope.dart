import 'package:flutter/widgets.dart';

import 'media_repository.dart';

/// Puts one [MediaRepository] within reach of every screen that uploads a file.
///
/// Three unrelated surfaces upload photos — a vendor's menu item, a student's
/// avatar, an attachment on a request — and none of them is worth threading a
/// repository through the module tree for. They ask for it here instead.
class MediaScope extends InheritedWidget {
  const MediaScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final MediaRepository repository;

  /// The repository, or null where no scope is installed — a screen shown in a
  /// test harness, for instance, which should hide its upload control rather
  /// than crash.
  static MediaRepository? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MediaScope>()
      ?.repository;

  static MediaRepository of(BuildContext context) {
    final repository = maybeOf(context);
    assert(repository != null, 'No MediaScope found in the widget tree.');
    return repository!;
  }

  @override
  bool updateShouldNotify(MediaScope oldWidget) =>
      repository != oldWidget.repository;
}
