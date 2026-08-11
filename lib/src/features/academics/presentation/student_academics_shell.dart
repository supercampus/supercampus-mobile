import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';

/// Student/parent view of Academics. Staff marking stays in FacultyPortalScreen.
class StudentAcademicsShell extends StatefulWidget {
  const StudentAcademicsShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.initialAction,
  });

  final UserSession session;
  final VoidCallback onExitModule;
  final String? initialAction;

  @override
  State<StudentAcademicsShell> createState() => _StudentAcademicsShellState();
}

class _StudentAcademicsShellState extends State<StudentAcademicsShell> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: const Color(0xFF4A4E9C),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.home_outlined),
        onPressed: widget.onExitModule,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Academics'),
          Text(
            widget.session.displayName,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _attendance(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _marks(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _analysis(),
        ],
      ),
    ),
  );

  Widget _attendance() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Attendance overview',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      const Text(
        'Your attendance by subject',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      _summaryCard(
        'Overall attendance',
        '82%',
        '82 of 100 classes attended',
        Colors.green,
      ),
      const SizedBox(height: 14),
      for (final item in const [
        ('Digital Signal Processing', '88%', 0.88),
        ('VLSI Design', '79%', 0.79),
        ('Microwave Engineering', '74%', 0.74),
        ('Antennas & Propagation', '86%', 0.86),
      ])
        _progressCard(item.$1, item.$2, item.$3),
    ],
  );

  Widget _marks() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Marks and results',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      const Text(
        'Continuous assessment and published results',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      for (final item in const [
        ('Digital Signal Processing', 'CIA 1: 42 / 50', 'CIA 2: 38 / 50'),
        ('VLSI Design', 'CIA 1: 35 / 50', 'CIA 2: 40 / 50'),
        ('Microwave Engineering', 'CIA 1: 44 / 50', 'CIA 2: 41 / 50'),
      ])
        Card(
          elevation: 0,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)),
            title: Text(item.$1),
            subtitle: Text('${item.$2}  ·  ${item.$3}'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
    ],
  );

  Widget _analysis() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Academic analysis',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      const Text(
        'A quick view of your academic progress',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _summaryCard(
              'Current CGPA',
              '7.42',
              'Target: 8.00',
              const Color(0xFF4A4E9C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              'Credits',
              '118',
              'of 160 completed',
              Colors.orange,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What needs attention',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: Icon(
                  Icons.warning_amber_outlined,
                  color: Colors.orange,
                ),
                title: Text('Microwave Engineering attendance is below 75%'),
                contentPadding: EdgeInsets.zero,
              ),
              const ListTile(
                leading: Icon(Icons.trending_up_outlined, color: Colors.green),
                title: Text('Your CIA 2 average improved by 6%'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _summaryCard(
    String title,
    String value,
    String subtitle,
    Color color,
  ) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_outlined, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _progressCard(String title, String value, double progress) {
    final color = progress < .75 ? Colors.orange : Colors.green;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title)),
                Text(
                  value,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              color: color,
              backgroundColor: color.withValues(alpha: .12),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
    );
  }
}
