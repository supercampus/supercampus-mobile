import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/approval_portal_repository.dart';
import '../data/gatepass_repository.dart';

class ApprovalPortalScreen extends StatefulWidget {
  const ApprovalPortalScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.onSignOut,
    required this.viewerKind,
  });

  final UserSession session;
  final ApprovalPortalRepository repository;
  final VoidCallback onSignOut;
  final String viewerKind;

  @override
  State<ApprovalPortalScreen> createState() => _ApprovalPortalScreenState();
}

class _ApprovalPortalScreenState extends State<ApprovalPortalScreen> {
  ApprovalPortalStore? _store;
  String? _error;
  final Set<String> _busy = {};

  bool get _isAdmin => widget.viewerKind == 'admin';
  bool get _isParent => widget.viewerKind == 'parent';
  bool get _isWarden => widget.viewerKind == 'warden';
  bool get _isPrincipal => widget.viewerKind == 'principal';
  bool get _isLeaveApprover =>
      widget.viewerKind == 'advisor_or_hod' || _isPrincipal;

  String _statusFilter = 'all';

  String get _portalTitle => switch (widget.viewerKind) {
    'admin' => 'Gatepass Approvals',
    'parent' => 'Parent / Guardian',
    'warden' => 'Warden approvals',
    'principal' => 'Principal approvals',
    _ => 'Advisor / HOD approvals',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final value = await widget.repository.load();
      if (mounted) setState(() => _store = value);
    } on GatepassException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The approval portal could not be loaded.');
      }
    }
  }

  Future<void> _review(ApprovalRequest request, bool approved) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${approved ? 'Approve' : 'Reject'} ${request.passType == 'leave_pass' ? 'leave pass' : 'outpass'}?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.studentName} • ${request.destination}'),
            const SizedBox(height: 14),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: approved ? 'Approval note (optional)' : 'Reason',
                hintText: approved
                    ? (_isParent
                          ? 'Approved with parent consent'
                          : 'Add an approval note')
                    : 'Tell the student why this was rejected',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approved
                  ? const Color(0xFF167447)
                  : const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approved ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.add(request.id));
    try {
      await widget.repository.decide(
        requestId: request.id,
        approved: approved,
        note: note.text,
      );
      await _load();
      if (!mounted) return;
      final message = approved
          ? _isAdmin
                ? 'Pass approved by Admin. The student pass is ready.'
                : _isParent
                ? 'Parent consent recorded. The warden has been notified.'
                : _isWarden
                ? 'Warden approval recorded. The student QR is ready.'
                : _isPrincipal
                ? 'Principal approval recorded. The student QR is ready for security.'
                : 'Advisor / HOD approval recorded. The principal has been notified.'
          : _isAdmin
          ? 'Gatepass rejected by Admin. The student has been notified.'
          : _isLeaveApprover
          ? 'Leave pass rejected. The student has been notified.'
          : _isParent
          ? 'Rejected by parent. The student has been notified.'
          : 'Rejected by warden. Parent and student have been notified.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: approved
              ? const Color(0xFF167447)
              : const Color(0xFFC62828),
        ),
      );
    } on GatepassException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(request.id));
    }
  }

  void _showGatepassDetail(ApprovalRequest request) {
    final status = _ApprovalCard._status(request.state);
    final isActionable = request.canDecide(widget.viewerKind);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _PassTypePill(passType: request.passType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.studentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(label: status.$1, color: status.$2),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _detailRow(Icons.place_outlined, 'Destination', request.destination),
            _detailRow(Icons.description_outlined, 'Reason', request.reason),
            _detailRow(
              Icons.logout_outlined,
              'Departure',
              _ApprovalCard._stamp(request.departureAt),
            ),
            _detailRow(
              Icons.login_outlined,
              'Return',
              _ApprovalCard._stamp(request.returnAt),
            ),
            _detailRow(
              Icons.calendar_today_outlined,
              'Applied at',
              _ApprovalCard._stamp(request.createdAt),
            ),
            if (request.decisionNote != null && request.decisionNote!.isNotEmpty)
              _detailRow(
                Icons.comment_outlined,
                'Decision note',
                request.decisionNote!,
              ),
            if (request.qrPayload != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    QrImageView(data: request.qrPayload!, size: 160),
                    const SizedBox(height: 4),
                    const Text(
                      'Gatepass QR Verification Code',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
            if (isActionable) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _review(request, false);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF167447),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _review(request, true);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F4),
      appBar: AppBar(
        title: Text(_portalTitle),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final store = _store;
    if (store == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final all = store.requests;
    final pendingTotal = all
        .where((r) => r.canDecide(widget.viewerKind) || r.state.startsWith('pending'))
        .toList(growable: false);
    final approvedTotal = all
        .where((r) => r.state == 'approved')
        .toList(growable: false);
    final rejectedTotal = all
        .where((r) => r.state == 'rejected')
        .toList(growable: false);

    final filteredRequests = switch (_statusFilter) {
      'pending' => pendingTotal,
      'approved' => approvedTotal,
      'rejected' => rejectedTotal,
      _ => all,
    };

    final actionable = filteredRequests
        .where((request) => request.canDecide(widget.viewerKind))
        .toList(growable: false);
    final otherRequests = filteredRequests
        .where((request) => !request.canDecide(widget.viewerKind))
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Text(
            'Good ${_greeting()}, ${widget.session.displayName.split(' ').first}',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(switch (widget.viewerKind) {
            'admin' =>
              'Review and manage all student gatepass and outpass requests.',
            'parent' =>
              'Verify your child and give consent for hostel outpass requests.',
            'warden' => 'Review parent-consented hostel outpass requests.',
            'principal' =>
              'Give final approval to advisor-approved college-hours leave passes.',
            _ =>
              'Review leave passes for students in your assigned department.',
          }, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('All (${all.length})'),
                  selected: _statusFilter == 'all',
                  onSelected: (_) => setState(() => _statusFilter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Pending (${pendingTotal.length})'),
                  selected: _statusFilter == 'pending',
                  onSelected: (_) => setState(() => _statusFilter = 'pending'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Approved (${approvedTotal.length})'),
                  selected: _statusFilter == 'approved',
                  onSelected: (_) => setState(() => _statusFilter = 'approved'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Rejected (${rejectedTotal.length})'),
                  selected: _statusFilter == 'rejected',
                  onSelected: (_) => setState(() => _statusFilter = 'rejected'),
                ),
              ],
            ),
          ),
          if (_isParent) ...[
            const SizedBox(height: 20),
            if (store.children.isEmpty)
              const _EmptyCard(
                icon: Icons.link_off,
                text: 'No child is linked to this parent account yet.',
              )
            else
              for (final child in store.children) _ChildCard(child: child),
          ],
          if (actionable.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Needs your decision',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ),
                _CountPill(count: actionable.length),
              ],
            ),
            const SizedBox(height: 12),
            for (final request in actionable)
              _ApprovalCard(
                request: request,
                busy: _busy.contains(request.id),
                onTap: () => _showGatepassDetail(request),
                onApprove: () => _review(request, true),
                onReject: () => _review(request, false),
              ),
          ],
          if (otherRequests.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    actionable.isEmpty ? 'Gatepass requests' : 'Other requests / History',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                ),
                _CountPill(count: otherRequests.length),
              ],
            ),
            const SizedBox(height: 12),
            for (final request in otherRequests)
              _ApprovalCard(
                request: request,
                compact: true,
                onTap: () => _showGatepassDetail(request),
              ),
          ],
          if (filteredRequests.isEmpty) ...[
            const SizedBox(height: 20),
            _EmptyCard(
              icon: Icons.verified_outlined,
              text: _statusFilter == 'pending'
                  ? 'No gatepass is waiting for decision.'
                  : 'No gatepasses found matching filter.',
            ),
          ],
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});
  final ApprovalChild child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFD8E9DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFDDF3E6),
              backgroundImage: child.photoUrl == null
                  ? null
                  : NetworkImage(child.photoUrl!),
              child: child.photoUrl == null
                  ? Text(
                      child.name.isEmpty ? 'S' : child.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF167447),
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: Color(0xFF167447), size: 17),
                      SizedBox(width: 5),
                      Text(
                        'Your verified child',
                        style: TextStyle(
                          color: Color(0xFF167447),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    child.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('${child.rollNumber} • ${child.department}'),
                  if (child.hostel.isNotEmpty)
                    Text(
                      '${child.hostel}${child.room.isEmpty ? '' : ' • ${child.room}'}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.request,
    this.busy = false,
    this.compact = false,
    this.onTap,
    this.onApprove,
    this.onReject,
  });

  final ApprovalRequest request;
  final bool busy;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final status = _status(request.state);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD8E9DF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                _PassTypePill(passType: request.passType),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.studentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusPill(label: status.$1, color: status.$2),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.destination,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              request.reason,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Text('Out: ${_stamp(request.departureAt)}'),
            Text('Return: ${_stamp(request.returnAt)}'),
            if (request.decisionNote != null) ...[
              const SizedBox(height: 8),
              Text(
                request.decisionNote!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (request.qrPayload != null) ...[
              const SizedBox(height: 14),
              Center(
                child: Column(
                  children: [
                    QrImageView(data: request.qrPayload!, size: 150),
                    const Text('Approved gatepass QR'),
                  ],
                ),
              ),
            ],
            if (!compact && onApprove != null && onReject != null) ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onApprove,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  static String _stamp(DateTime value) {
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year}  ${value.hour}:$minute';
  }

  static (String, Color) _status(String state) => switch (state) {
    'pending_parent' => ('Parent review', const Color(0xFFE38B00)),
    'pending_warden' => ('Warden review', const Color(0xFF3558D4)),
    'approved' => ('Approved ✓', const Color(0xFF167447)),
    'rejected' => ('Rejected', const Color(0xFFC62828)),
    'cancelled' => ('Cancelled', Colors.grey),
    _ => (state.replaceAll('_', ' '), Colors.grey),
  };
}

class _PassTypePill extends StatelessWidget {
  const _PassTypePill({required this.passType});
  final String passType;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFECEAFF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      passType == 'leave_pass' ? 'Leave pass' : 'Outpass',
      style: const TextStyle(fontSize: 11, color: AppColors.gateBlue),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 15,
    backgroundColor: const Color(0xFF167447),
    foregroundColor: Colors.white,
    child: Text('$count'),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFD8E9DF)),
    ),
    child: Column(
      children: [
        Icon(icon, color: const Color(0xFF167447), size: 32),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}
