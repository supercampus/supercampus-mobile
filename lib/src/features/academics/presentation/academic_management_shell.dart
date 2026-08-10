import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/academic_models.dart';
import '../data/mock_academic_repository.dart';

class AcademicManagementShell extends StatefulWidget {
  const AcademicManagementShell({
    super.key,
    required this.session,
    required this.onExitModule,
  });
  final UserSession session;
  final VoidCallback onExitModule;
  @override
  State<AcademicManagementShell> createState() =>
      _AcademicManagementShellState();
}

class _AcademicManagementShellState extends State<AcademicManagementShell> {
  final _repo = MockAcademicRepository();
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [_programmes(), _subjects(), _batches()];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A4E9C),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: widget.onExitModule,
        ),
        title: const Text('Academic Management'),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            label: 'Programmes',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Subjects',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Batches',
          ),
        ],
      ),
    );
  }

  void _add() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddAcademicSheet(
      tab: _tab,
      onAdded: (value) {
        setState(() {
          if (value is AcademicProgramme) _repo.programmes.insert(0, value);
          if (value is AcademicSubject) _repo.subjects.insert(0, value);
          if (value is AcademicBatch) _repo.batches.insert(0, value);
        });
        Navigator.of(context).pop();
      },
    ),
  );

  Widget _programmes() => _list('Programmes and courses', [
    for (final item in _repo.programmes)
      _AcademicCard(
        icon: Icons.school_outlined,
        title: item.name,
        subtitle: '${item.code} · ${item.duration}',
        status: item.status,
      ),
  ]);
  Widget _subjects() => _list('Subjects', [
    for (final item in _repo.subjects)
      _AcademicCard(
        icon: Icons.menu_book_outlined,
        title: item.name,
        subtitle: '${item.code} · ${item.programme}',
        status: '${item.credits} credits',
      ),
  ]);
  Widget _batches() => _list('Batches and sections', [
    for (final item in _repo.batches)
      _AcademicCard(
        icon: Icons.groups_outlined,
        title: '${item.name} · Section ${item.section}',
        subtitle: item.programme,
        status: '${item.students} students',
      ),
  ]);
  Widget _list(String title, List<Widget> cards) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      for (final card in cards) ...[card, const SizedBox(height: 10)],
    ],
  );
}

class _AcademicCard extends StatelessWidget {
  const _AcademicCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF4A4E9C).withValues(alpha: .1),
        child: Icon(icon, color: const Color(0xFF4A4E9C)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        status,
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
    ),
  );
}

class _AddAcademicSheet extends StatefulWidget {
  const _AddAcademicSheet({required this.tab, required this.onAdded});
  final int tab;
  final ValueChanged<Object> onAdded;
  @override
  State<_AddAcademicSheet> createState() => _AddAcademicSheetState();
}

class _AddAcademicSheetState extends State<_AddAcademicSheet> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    final value = switch (widget.tab) {
      0 => AcademicProgramme(
        code: _code.text.trim().isEmpty ? 'NEW-001' : _code.text.trim(),
        name: _name.text.trim(),
        duration: '3 years',
        status: 'Draft',
      ),
      1 => AcademicSubject(
        code: _code.text.trim().isEmpty ? 'NEW-001' : _code.text.trim(),
        name: _name.text.trim(),
        credits: 3,
        programme: 'B.Tech Computer Science',
      ),
      _ => AcademicBatch(
        name: _name.text.trim(),
        programme: 'B.Tech Computer Science',
        section: 'A',
        students: 0,
      ),
    };
    widget.onAdded(value);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add ${widget.tab == 0
                ? 'programme'
                : widget.tab == 1
                ? 'subject'
                : 'batch'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: widget.tab == 2 ? 'Batch name' : 'Name',
            ),
          ),
          if (widget.tab != 2)
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
    ),
  );
}
