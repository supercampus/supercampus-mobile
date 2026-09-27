import 'package:flutter/foundation.dart';

/// Bumped whenever the backend reports a newly published announcement
/// (`announcement.published` over the realtime socket). The Campus Wall and
/// the home announcement card listen to it and reload, so a post made from the
/// admin portal reaches an open student screen without a manual refresh.
final ValueNotifier<int> announcementRevision = ValueNotifier<int>(0);

/// Realtime event types that change what the wall should show.
const announcementEventTypes = {
  'announcement.published',
  'announcement.approved',
  'announcement.updated',
  'announcement.deleted',
};
