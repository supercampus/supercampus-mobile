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
    this.onSwitchRole,
  });

  final UserSession session;
  final VoidCallback? onExitModule;
  final VoidCallback onSignOut;
  final ValueChanged<UserRole>? onSwitchRole;

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
                icon: const Icon(Icons.arrow_back),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAllocator
                      ? 'Timetable Allocator Portal'
                      : 'Campus Timetable Management',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${widget.session.displayName} • ${widget.session.role.label}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.onSwitchRole != null)
            PopupMenuButton<UserRole>(
              tooltip: 'Switch Portal Role',
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              onSelected: widget.onSwitchRole,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  enabled: false,
                  child: Text('Switch Role (Demo mode):'),
                ),
                ...UserRole.values.map(
                  (r) => PopupMenuItem(
                    value: r,
                    child: Row(
                      children: [
                        Icon(
                          r == widget.session.role
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 16,
                          color: r == widget.session.role
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(r.label),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
