import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/announcement_composer.dart';
import '../../../core/widgets/module_section_switcher.dart';
import '../../authentication/data/auth_repository.dart';
import '../../scanner/presentation/scan_qr_screen.dart';
import '../data/librarian_repository.dart';
import '../data/library_lending_repository.dart';
import 'librarian_lending_screen.dart';

class LibrarianPortalScreen extends StatefulWidget {
  const LibrarianPortalScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.lendingRepository,
    required this.onSignOut,
    this.initialAction,
  });

  final UserSession session;
  final LibrarianRepository repository;
  final LibraryLendingRepository lendingRepository;
  final VoidCallback onSignOut;
  final String? initialAction;

  @override
  State<LibrarianPortalScreen> createState() => _LibrarianPortalScreenState();
}

class _LibrarianPortalScreenState extends State<LibrarianPortalScreen> {
  List<LibrarianRequest> _requests = const [];
  List<LibraryAnnouncement> _announcements = const [];
  LibrarianSettings? _settings;
  bool _loading = true;
  String? _error;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _selected = switch (widget.initialAction) {
      'logs' || 'download' => 1,
      'scan' => 3,
      _ => 0,
    };
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.repository.list(),
        widget.repository.settings().catchError(
          (_) => const LibrarianSettings(
            slotCapacity: 500,
            activeBookings: 0,
            completedVisits: 0,
          ),
        ),
        widget.repository.announcements().catchError(
          (_) => const <LibraryAnnouncement>[],
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = values[0] as List<LibrarianRequest>;
        _settings = values[1] as LibrarianSettings;
        _announcements = values[2] as List<LibraryAnnouncement>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _scan() async {
    final payload = await openScanQr(context, title: 'Scan library request');
    if (payload == null || !mounted) return;
    try {
      final request = await widget.repository.scan(payload);
      if (mounted) await _review(request);
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  Future<void> _review(LibrarianRequest request) async {
    final note = TextEditingController();
    final decision = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Validate request',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            Text(
              request.studentName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text(request.zoneName),
            Text(
              '${_stamp(request.visitStart)} – ${DateFormat('h:mm a').format(request.visitEnd)}',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'Decision note (optional)',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'rejected'),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, 'approved'),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (decision == null) {
      note.dispose();
      return;
    }
    try {
      await widget.repository.decide(request.id, decision, note: note.text);
      if (!mounted) return;
      _snack('Request $decision successfully.');
      await _load();
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    } finally {
      note.dispose();
    }
  }

  Future<void> _editCapacity() async {
    final controller = TextEditingController(
      text: '${_settings?.slotCapacity ?? 500}',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set available slot capacity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Maximum students per time slot',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await widget.repository.updateSlotCapacity(value);
      await _load();
      if (mounted) _snack('Library slot capacity updated.');
    } catch (error) {
      if (mounted) _snack(_message(error), error: true);
    }
  }

  Future<void> _createAnnouncement() async {
    final draft = await showAnnouncementComposer(
      context,
      heading: 'New library announcement',
      submitLabel: 'Send to admin for approval',
      supportingText:
          'The admin receives this request in the mobile app and by push notification.',
    );
    if (draft != null) {
      try {
        await widget.repository.createAnnouncement(
          type: draft.type,
          announcementDate: draft.date,
          title: draft.title,
          message: draft.description,
          attachmentName: draft.attachmentName,
          attachmentUrl: draft.attachmentUrl,
        );
        await _load();
        if (mounted) _snack('Announcement sent to admin for approval.');
      } catch (error) {
        if (mounted) _snack(_message(error), error: true);
      }
    }
  }

  Future<void> _openAnnouncementAttachment(LibraryAnnouncement item) async {
    final value = item.attachmentUrl;
    if (value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _snack('The attachment could not be opened.', error: true);
    }
  }

  Future<void> _chooseExport() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Download library logs'),
              subtitle: Text('Choose a preferred file format'),
            ),
            for (final entry in const [
              ('csv', 'CSV spreadsheet'),
              ('json', 'JSON data'),
              ('html', 'HTML report'),
              ('md', 'Markdown report'),
            ])
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(entry.$2),
                onTap: () => Navigator.pop(context, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (format != null) await _export(format);
  }

  Future<void> _export(String format) async {
    final now = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final rows = _requests
        .map(
          (request) => {
            'id': request.id,
            'student': request.studentName,
            'zone': request.zoneName,
            'visitStart': request.visitStart.toIso8601String(),
            'visitEnd': request.visitEnd.toIso8601String(),
            'status': request.status,
            'decisionNote': request.decisionNote ?? '',
            'createdAt': request.createdAt.toIso8601String(),
          },
        )
        .toList();
    final content = switch (format) {
      'json' => const JsonEncoder.withIndent('  ').convert(rows),
      'html' =>
        '<!doctype html><meta charset="utf-8"><title>Library logs</title><h1>Library logs</h1><table border="1" cellspacing="0" cellpadding="6"><tr><th>ID</th><th>Student</th><th>Zone</th><th>Start</th><th>End</th><th>Status</th><th>Note</th></tr>${rows.map((r) => '<tr>${['id', 'student', 'zone', 'visitStart', 'visitEnd', 'status', 'decisionNote'].map((key) => '<td>${_html('${r[key]}')}</td>').join()}</tr>').join()}</table>',
      'md' =>
        '| ID | Student | Zone | Start | End | Status | Note |\n|---|---|---|---|---|---|---|\n${rows.map((r) => '| ${r['id']} | ${r['student']} | ${r['zone']} | ${r['visitStart']} | ${r['visitEnd']} | ${r['status']} | ${r['decisionNote']} |').join('\n')}',
      _ =>
        'ID,Student,Zone,Visit start,Visit end,Status,Decision note\n${rows.map((r) => [r['id'], r['student'], r['zone'], r['visitStart'], r['visitEnd'], r['status'], r['decisionNote']].map((v) => '"${'$v'.replaceAll('"', '""')}"').join(',')).join('\n')}',
    };
    await FilePicker.saveFile(
      dialogTitle: 'Save library logs',
      fileName: 'supercampus-library-logs-$now.$format',
      type: FileType.custom,
      allowedExtensions: [format],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    if (mounted) _snack('Library logs prepared as ${format.toUpperCase()}.');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_home(), _logs(), _profile(), _scanPage()];
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.gateBlue,
        foregroundColor: Colors.white,
        title: Text(
          const [
            'Library home',
            'Library logs',
            'Librarian profile',
            'Scan request',
          ][_selected],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          ModuleSectionSwitcher(
            sections: const [
              ModuleSection(label: 'Home', icon: Icons.home_outlined),
              ModuleSection(label: 'Logs', icon: Icons.receipt_long_outlined),
              ModuleSection(label: 'Profile', icon: Icons.person_outline),
              ModuleSection(label: 'Scan', icon: Icons.qr_code_scanner),
            ],
            selectedIndex: _selected,
            onSelected: (value) => setState(() => _selected = value),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(_error!),
                    ),
                  )
                : IndexedStack(index: _selected, children: pages),
          ),
        ],
      ),
    );
  }

  Widget _home() {
    final pending = _requests
        .where((request) => request.status == 'pending')
        .toList();
    final settings = _settings!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Hello, ${widget.session.displayName}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        color: AppColors.gateBlue,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Slot availability',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _editCapacity,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Set'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${settings.available}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gateBlue,
                    ),
                  ),
                  Text(
                    'available of ${settings.slotCapacity} · ${settings.activeBookings} active bookings',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LibrarianLendingScreen(
                  repository: widget.lendingRepository,
                ),
              ),
            ),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Manage book lending & inventory'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _createAnnouncement,
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Post new book announcement'),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Awaiting validation', pending.length),
          if (pending.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text('No pending library requests.'),
              ),
            ),
          for (final request in pending)
            _requestCard(request, onTap: () => _review(request)),
          const SizedBox(height: 18),
          _sectionTitle('Announcements', _announcements.length),
          if (_announcements.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Text('No announcements submitted yet.'),
              ),
            ),
          for (final announcement in _announcements.take(5))
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(announcement.title),
                subtitle: Text(
                  '${announcement.type.toUpperCase()} · '
                  '${DateFormat('dd MMM yyyy').format(announcement.announcementDate)}\n'
                  '${announcement.message}\n${announcement.status.toUpperCase()}',
                ),
                isThreeLine: true,
                trailing: announcement.attachmentUrl == null
                    ? null
                    : IconButton(
                        tooltip: 'View details',
                        onPressed: () =>
                            _openAnnouncementAttachment(announcement),
                        icon: const Icon(Icons.attach_file),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logs() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Request history',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FilledButton.icon(
            onPressed: _chooseExport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        '${_requests.length} auditable request records · CSV, JSON, HTML or Markdown',
        style: const TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 16),
      if (_requests.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Text('No library history yet.'),
          ),
        ),
      for (final request in _requests) _requestCard(request),
    ],
  );

  Widget _profile() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFFECEAFF),
                child: Text(
                  widget.session.displayName.isEmpty
                      ? 'L'
                      : widget.session.displayName[0],
                  style: const TextStyle(
                    fontSize: 28,
                    color: AppColors.gateBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.session.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(widget.session.email),
              const SizedBox(height: 4),
              const Text(
                'Library · Librarian',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: widget.onSignOut,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );

  Widget _scanPage() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.qr_code_scanner,
            size: 82,
            color: AppColors.gateBlue,
          ),
          const SizedBox(height: 18),
          Text(
            'Scan student library QR',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Validate the request, then approve or reject it.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Open scanner'),
          ),
        ],
      ),
    ),
  );

  Widget _requestCard(LibrarianRequest request, {VoidCallback? onTap}) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(request.studentName.isEmpty ? 'S' : request.studentName[0]),
      ),
      title: Text(request.studentName),
      subtitle: Text(
        '${request.zoneName}\n${_stamp(request.visitStart)} · ${request.status.toUpperCase()}',
      ),
      isThreeLine: true,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    ),
  );

  Widget _sectionTitle(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
        Chip(label: Text('$count')),
      ],
    ),
  );

  String _stamp(DateTime value) => DateFormat('d MMM, h:mm a').format(value);
  String _message(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');
  String _html(String value) => const HtmlEscape().convert(value);
  void _snack(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
}
