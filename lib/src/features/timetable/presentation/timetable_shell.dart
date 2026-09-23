import 'package:flutter/material.dart';

import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/access/module_catalog.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/backend_timetable_repository.dart';
import '../data/mock_timetable_repository.dart';
import '../data/timetable_repository.dart';
import 'faculty_dashboard_screen.dart';
import 'view_only_timetable_screen.dart';

class TimetableShell extends StatefulWidget {
  const TimetableShell({
    super.key,
    required this.session,
    required this.canConfigure,
    required this.scope,
    this.baseUrl,
    this.accessTokenProvider,
    this.onExitModule,
    required this.onSignOut,
    this.initialAction,
  });

  final UserSession session;
  final bool canConfigure;

  /// How far this person's timetable grant reaches. `own` is a learner reading
  /// their own week, `section` someone teaching it.
  final PermissionScope scope;
  final String? baseUrl;
  final AccessTokenProvider? accessTokenProvider;
  final VoidCallback? onExitModule;
  final VoidCallback onSignOut;
  final String? initialAction;

  @override
  State<TimetableShell> createState() => _TimetableShellState();
}

class _TimetableShellState extends State<TimetableShell> {
  late Future<TimetableRepository> _repository;

  @override
  void initState() {
    super.initState();
    _repository = _loadRepository();
  }

  Future<TimetableRepository> _loadRepository() async {
    final baseUrl = widget.baseUrl;
    final provider = widget.accessTokenProvider;
    if (baseUrl == null || provider == null) {
      return MockTimetableRepository.shared;
    }
    try {
      final repo = await BackendTimetableRepository.load(
        baseUrl: baseUrl,
        accessTokenProvider: provider,
      );
      return repo;
    } catch (e) {
      debugPrint('Backend timetable loading failed, falling back to mock schedule: $e');
      return MockTimetableRepository.shared;
    }
  }

  void _retry() => setState(() => _repository = _loadRepository());

  @override
  Widget build(BuildContext context) {
    final isAllocator = widget.canConfigure;
    // A class advisor can hold department scope while still teaching classes
    // outside that department. Portal family identifies the teaching surface;
    // the repository then filters the published rows by the signed-in user.
    // Scope alone cannot make this decision because it describes reach, not
    // whether the person is faculty.
    final isFaculty =
        !isAllocator && widget.session.activePortalFamily == PortalFamily.staff;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: widget.onExitModule != null
            ? ModuleBackButton(
                onPressed: widget.onExitModule!,
                color: Colors.black,
              )
            : null,
        title: const Text('Timetable', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<TimetableRepository>(
        future: _repository,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const TimetableLoadingSkeleton();
          }
          if (snapshot.hasError || snapshot.data == null) {
            final error = snapshot.error;
            final message = error is TimetableLoadException
                ? error.message
                : 'The published timetable could not be loaded.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          final repository = snapshot.data!;
          if (isAllocator) {
            return ViewOnlyTimetableScreen(
              canConfigure: widget.canConfigure,
              session: widget.session,
              repository: repository,
            );
          }
          if (isFaculty) {
            return FacultyDashboardScreen(
              session: widget.session,
              repository: repository,
              initialSection: widget.initialAction == 'substitution' ? 1 : 0,
            );
          }
          return ViewOnlyTimetableScreen(
            canConfigure: widget.canConfigure,
            session: widget.session,
            repository: repository,
          );
        },
      ),
    );
  }
}
