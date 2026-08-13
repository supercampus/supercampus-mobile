import 'package:flutter/material.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/mock_library_repository.dart';
import 'library_bookings_screen.dart';

/// Thin shell that owns the [MockLibraryRepository] and delegates all UI
/// to [LibraryBookingsScreen]. When a real backend is wired, replace
/// [MockLibraryRepository] with an abstract interface and inject it here.
class LibraryShell extends StatefulWidget {
  const LibraryShell({
    super.key,
    required this.session,
    required this.onExitModule,
  });

  final UserSession session;
  final VoidCallback onExitModule;

  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell> {
  late final MockLibraryRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockLibraryRepository();
  }

  @override
  Widget build(BuildContext context) {
    return LibraryBookingsScreen(
      session: widget.session,
      repository: _repository,
      onExitModule: widget.onExitModule,
    );
  }
}
