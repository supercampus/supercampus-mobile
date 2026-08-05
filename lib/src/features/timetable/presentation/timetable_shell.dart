import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_timetable_repository.dart';
import 'allocator_dashboard_screen.dart';
import 'view_only_timetable_screen.dart';

class TimetableShell extends StatefulWidget {
  const TimetableShell({
    super.key,
    required this.session,
    this.onExitModule,
    required this.onSignOut,
  });

  final UserSession session;
  final VoidCallback? onExitModule;
  final VoidCallback onSignOut;

  @override
  State<TimetableShell> createState() => _TimetableShellState();
}

class _TimetableShellState extends State<TimetableShell> {
  final _repository = MockTimetableRepository();

  @override
  Widget build(BuildContext context) {
    final isAllocator = widget.session.role == UserRole.timetableAllocator;
    final primaryColor =
        isAllocator ? const Color(0xFF00695C) : AppColors.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: widget.onExitModule != null
            ? IconButton(
                tooltip: 'Modules Home',
                icon: const Icon(Icons.home),
                onPressed: widget.onExitModule,
              )
            : null,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.table_chart,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAllocator
                        ? 'Timetable Allocator Portal'
                        : 'Campus Timetable Management',
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${widget.session.displayName} • ${widget.session.role.label}',
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: widget.onSignOut,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isAllocator
          ? AllocatorDashboardScreen(
              session: widget.session,
              repository: _repository,
            )
          : ViewOnlyTimetableScreen(
              session: widget.session,
              repository: _repository,
            ),
    );
  }
}
