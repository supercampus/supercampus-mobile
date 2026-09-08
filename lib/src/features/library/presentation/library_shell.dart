import 'package:flutter/material.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/backend_library_repository.dart';
import '../data/library_lending_repository.dart';
import '../data/library_repository.dart';
import '../data/mock_library_repository.dart';
import 'library_bookings_screen.dart';
import 'library_lending_screen.dart';

/// Thin shell that owns the [MockLibraryRepository] and delegates all UI
/// to [LibraryBookingsScreen]. When a real backend is wired, replace
/// [MockLibraryRepository] with an abstract interface and inject it here.
class LibraryShell extends StatefulWidget {
  const LibraryShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.initialAction,
    this.baseUrl,
    this.accessTokenProvider,
  });

  final UserSession session;
  final VoidCallback onExitModule;
  final String? initialAction;
  final String? baseUrl;
  final AccessTokenProvider? accessTokenProvider;

  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell> {
  late final LibraryRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.baseUrl == null || widget.accessTokenProvider == null
        ? MockLibraryRepository()
        : BackendLibraryRepository(
            baseUrl: widget.baseUrl!,
            accessTokenProvider: widget.accessTokenProvider!,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.baseUrl != null && widget.accessTokenProvider != null) {
      return LibraryLendingScreen(
        session: widget.session,
        repository: LibraryLendingRepository(
          baseUrl: widget.baseUrl!,
          accessTokenProvider: widget.accessTokenProvider!,
        ),
        slotRepository: _repository,
        onExitModule: widget.onExitModule,
      );
    }
    return LibraryBookingsScreen(
      session: widget.session,
      repository: _repository,
      onExitModule: widget.onExitModule,
      initialAction: widget.initialAction,
    );
  }
}
