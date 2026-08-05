import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_security_repository.dart';
import '../data/security_models.dart';

class SecurityPortalScreen extends StatefulWidget {
  const SecurityPortalScreen({
    super.key,
    required this.session,
    required this.onSignOut,
    this.onExitModule,
  });

  final UserSession session;
  final VoidCallback onSignOut;
  final VoidCallback? onExitModule;

  @override
  State<SecurityPortalScreen> createState() => _SecurityPortalScreenState();
}

class _SecurityPortalScreenState extends State<SecurityPortalScreen> {
  final _repository = MockSecurityRepository();
  int _currentTab = 0;

  final _lookupController = TextEditingController(text: 'GP-2026-881');
  GateVerificationResult? _lastResult;
  bool _isSearching = false;

  late List<SecurityActiveOutpass> _activeOutpasses;
  late List<VisitorPassLog> _visitorLogs;
  late List<SecurityAlert> _alerts;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _activeOutpasses = _repository.getActiveOutpasses();
      _visitorLogs = _repository.getVisitorLogs();
      _alerts = _repository.getAlerts();
    });
  }

  void _verifyPass(String code) {
    setState(() => _isSearching = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _lastResult = _repository.verifyCode(code);
          _isSearching = false;
        });
      }
    });
  }

  void _approveGateMovement(String passId, String type) {
    _repository.recordGateAction(passId, type);
    _refreshData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gate movement recorded ($type) for Pass #$passId'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
    setState(() => _lastResult = null);
  }

  void _registerVisitorDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final visitPersonCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_outlined, color: Color(0xFFD9383A)),
            SizedBox(width: 8),
            Text('Register Walk-in Guest'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Visitor Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: visitPersonCtrl,
                decoration:
                    const InputDecoration(labelText: 'Person/Dept to Visit'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: purposeCtrl,
                decoration: const InputDecoration(labelText: 'Purpose of Visit'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD9383A),
            ),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final newLog = VisitorPassLog(
                  id: 'VIS-${DateTime.now().millisecondsSinceEpoch % 1000}',
                  visitorName: nameCtrl.text,
                  phone: phoneCtrl.text.isEmpty ? '+1 555-0000' : phoneCtrl.text,
                  personToVisit: visitPersonCtrl.text.isEmpty
                      ? 'Administration'
                      : visitPersonCtrl.text,
                  relationship: 'Guest',
                  purpose: purposeCtrl.text.isEmpty
                      ? 'General Inquiry'
                      : purposeCtrl.text,
                  checkInTime: DateTime.now(),
                  isCheckedIn: true,
                  badgeNumber:
                      'V-${(DateTime.now().millisecondsSinceEpoch % 20) + 1}',
                );
                _repository.addVisitorLog(newLog);
                _refreshData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Visitor ${newLog.visitorName} issued badge ${newLog.badgeNumber}'),
                  ),
                );
              }
            },
            child: const Text('Issue Pass & Check In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
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
                color: const Color(0xFFD9383A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Campus Security Portal',
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Gate: ${widget.session.departmentOrWard ?? "Main Gate"}',
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
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildGateScanTab(),
          _buildActiveOutpassesTab(),
          _buildVisitorLogTab(),
          _buildSecurityAlertsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Gate Verify',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${_activeOutpasses.length}'),
              child: const Icon(Icons.exit_to_app),
            ),
            label: 'Active Passes',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text(
                  '${_visitorLogs.where((v) => v.isCheckedIn).length}'),
              child: const Icon(Icons.badge_outlined),
            ),
            label: 'Visitors',
          ),
          const NavigationDestination(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Emergency Desk',
          ),
        ],
      ),
    );
  }

  Widget _buildGateScanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.qr_code_scanner,
                              color: Color(0xFFD9383A), size: 28),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gate Pass Scanner & Verification',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Scan QR payload or enter Gate Pass ID / Roll Number',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _lookupController,
                              decoration: const InputDecoration(
                                labelText: 'Gate Pass Code / Roll No',
                                prefixIcon: Icon(Icons.search),
                                hintText: 'e.g. GP-2026-881',
                              ),
                              onSubmitted: _verifyPass,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                            onPressed: _isSearching
                                ? null
                                : () => _verifyPass(_lookupController.text),
                            icon: _isSearching
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.verified_user),
                            label: const Text('Verify'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Quick Demo Scan Triggers:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.check_circle,
                                size: 16, color: Colors.green),
                            label: const Text('Valid Pass (Alex)'),
                            onPressed: () {
                              _lookupController.text = 'GP-2026-881';
                              _verifyPass('GP-2026-881');
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.timer_off,
                                size: 16, color: Colors.amber),
                            label: const Text('Expired Pass (Rohan)'),
                            onPressed: () {
                              _lookupController.text = 'GP-EXPIRED';
                              _verifyPass('GP-EXPIRED');
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.block,
                                size: 16, color: Colors.red),
                            label: const Text('Restricted Pass (Vikram)'),
                            onPressed: () {
                              _lookupController.text = 'GP-RESTRICT';
                              _verifyPass('GP-RESTRICT');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_lastResult != null) ...[
                const SizedBox(height: 20),
                _buildVerificationCard(_lastResult!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard(GateVerificationResult res) {
    final (statusColor, statusIcon, statusTitle) = switch (res.status) {
      PassVerificationStatus.valid => (
          const Color(0xFF2E7D32),
          Icons.verified,
          'ENTRY / EXIT APPROVED'
        ),
      PassVerificationStatus.expired => (
          Colors.orange.shade800,
          Icons.error_outline,
          'EXPIRED GATE PASS'
        ),
      PassVerificationStatus.restricted => (
          const Color(0xFFD9383A),
          Icons.block,
          'RESTRICTED / BLOCKED PASS'
        ),
      PassVerificationStatus.invalid => (
          Colors.red.shade900,
          Icons.cancel,
          'INVALID CODE'
        ),
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor, width: 2),
      ),
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  '#${res.passId}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Text(
                        res.studentName.substring(0, 1),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            res.studentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${res.rollNumber} • ${res.department}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            res.hostelRoom,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                Text(
                  'Pass Details:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                _detailRow('Pass Type', res.passType),
                _detailRow('Status Reason', res.statusReason),
                _detailRow(
                  'Parent Consent',
                  res.parentApproved ? 'Verified' : 'Pending',
                  valueColor: res.parentApproved ? Colors.green : Colors.red,
                ),
                _detailRow(
                  'Warden Approval',
                  res.wardenApproved ? 'Verified' : 'Pending / Required',
                  valueColor: res.wardenApproved ? Colors.green : Colors.amber,
                ),
                const SizedBox(height: 20),
                if (res.status == PassVerificationStatus.valid) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                          ),
                          onPressed: () => _approveGateMovement(
                              res.passId, 'OUTPASS EXIT'),
                          icon: const Icon(Icons.logout),
                          label: const Text('Log Student Exit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                          onPressed: () => _approveGateMovement(
                              res.passId, 'OUTPASS ENTRY'),
                          icon: const Icon(Icons.login),
                          label: const Text('Log Student Entry'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Text(
                      'Action Required: Inform student to contact Warden / Chief Warden for clearance.',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOutpassesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Student Outpasses',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${_activeOutpasses.length} students currently off-campus',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._activeOutpasses.map((pass) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: pass.isOverdue
                    ? const Color(0xFFD9383A)
                    : Colors.grey.shade200,
                width: pass.isOverdue ? 1.5 : 1,
              ),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: pass.isOverdue
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFE8F5E9),
                    child: Icon(
                      pass.isOverdue ? Icons.timer_off : Icons.directions_walk,
                      color: pass.isOverdue
                          ? const Color(0xFFD9383A)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              pass.studentName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: pass.isOverdue
                                    ? const Color(0xFFD9383A)
                                    : const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pass.statusLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pass.rollNumber} • ${pass.passType} to ${pass.destination}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        _approveGateMovement(pass.id, 'RETURNED TO CAMPUS'),
                    child: const Text('Log Return'),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVisitorLogTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campus Visitor Log',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Manage guest badges and check-ins',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD9383A),
              ),
              onPressed: _registerVisitorDialog,
              icon: const Icon(Icons.add),
              label: const Text('Walk-in Guest'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._visitorLogs.map((log) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      log.badgeNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.visitorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Visiting: ${log.personToVisit} (${log.relationship})',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                        Text(
                          'Purpose: ${log.purpose} • Phone: ${log.phone}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (log.isCheckedIn) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade800,
                      ),
                      onPressed: () {
                        _repository.checkoutVisitor(log.id);
                        _refreshData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Visitor ${log.visitorName} checked out.'),
                          ),
                        );
                      },
                      child: const Text('Check Out'),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Checked Out',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSecurityAlertsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Security Emergency & Incident Control',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Real-time broadcasts and incident logs',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: const Color(0xFFFFF1F2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFFECDD3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Color(0xFFE11D48), size: 36),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gate Emergency Control',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9F1239),
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Trigger instant campus perimeter alert or gate lockdown.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFBE123C)),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('SECURITY ALERT BROADCAST SENT'),
                        backgroundColor: Color(0xFFE11D48),
                      ),
                    );
                  },
                  child: const Text('Broadcast Alert'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Recent Incident Log:',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 10),
        ..._alerts.map((alert) {
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.notifications_active_outlined,
                    color: Color(0xFF475569)),
              ),
              title: Text(
                alert.title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('${alert.description}\nLocation: ${alert.location}'),
              trailing: Text(
                alert.severity,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: alert.severity == 'High' ? Colors.red : Colors.orange,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
