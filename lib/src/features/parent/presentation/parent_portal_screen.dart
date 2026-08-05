import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_parent_repository.dart';
import '../data/parent_models.dart';

class ParentPortalScreen extends StatefulWidget {
  const ParentPortalScreen({
    super.key,
    required this.session,
    required this.onSignOut,
    this.onExitModule,
  });

  final UserSession session;
  final VoidCallback onSignOut;
  final VoidCallback? onExitModule;

  @override
  State<ParentPortalScreen> createState() => _ParentPortalScreenState();
}

class _ParentPortalScreenState extends State<ParentPortalScreen> {
  final _repository = MockParentRepository();
  int _currentTab = 0;

  late WardProfile _ward;
  late List<ParentOutpassRequest> _outpassRequests;
  late List<WardFeeItem> _fees;
  late List<WardSubjectAttendance> _attendanceList;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _ward = _repository.getWardProfile();
      _outpassRequests = _repository.getOutpassRequests();
      _fees = _repository.getFees();
      _attendanceList = _repository.getAttendance();
    });
  }

  void _reviewPassDialog(ParentOutpassRequest req) {
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review ${req.requestType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ward: ${req.wardName}'),
            Text('Destination: ${req.destination}'),
            Text('Reason: ${req.reason}'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Parent Note (Optional)',
                hintText: 'e.g. Approved for family event',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              _repository.reviewOutpass(req.id, false, noteCtrl.text);
              _refreshData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Outpass request rejected.')),
              );
            },
            child: const Text('Reject Pass'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            onPressed: () {
              _repository.reviewOutpass(req.id, true, noteCtrl.text);
              _refreshData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Outpass request approved! Warden notified.'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            },
            child: const Text('Approve Outpass'),
          ),
        ],
      ),
    );
  }

  void _topupWalletDialog() {
    final amountCtrl = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Top-Up Canteen Wallet'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Child: ${_ward.name}'),
            Text('Current Balance: ₹${_ward.canteenBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount to add (₹)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [200, 500, 1000].map((amt) {
                return ActionChip(
                  label: Text('₹$amt'),
                  onPressed: () => amountCtrl.text = '$amt',
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            onPressed: () {
              final val = double.tryParse(amountCtrl.text) ?? 0;
              if (val > 0) {
                _repository.topupCanteenWallet(val);
                _refreshData();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added ₹$val to ${_ward.name}\'s wallet!'),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );
              }
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _outpassRequests.where((r) => r.status.contains('Pending')).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4332),
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
                color: const Color(0xFF2D6A4F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.family_restroom,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Parents Portal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Ward: ${_ward.name} (${_ward.rollNumber})',
                    maxLines: 1,
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
          _buildWardOverviewTab(),
          _buildOutpassApprovalsTab(),
          _buildFeesAndWalletTab(),
          _buildAcademicsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Ward Overview',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.approval),
            ),
            label: 'Outpass Approvals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Fees & Wallet',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            label: 'Academics',
          ),
        ],
      ),
    );
  }

  Widget _buildWardOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
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
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFD8F3DC),
                      child: Text(
                        _ward.name.substring(0, 1),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1B4332),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ward.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_ward.department} • ${_ward.semester}',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted),
                          ),
                          Text(
                            '${_ward.hostelName}, ${_ward.roomNumber}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Campus Location',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            Text(
                              _ward.campusStatus,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2D6A4F),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Overall Attendance',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            Text(
                              '${_ward.overallAttendancePercentage}%',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Actions for Ward:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_card,
                title: 'Top-Up Wallet',
                subtitle: '₹${_ward.canteenBalance.toStringAsFixed(0)} Balance',
                color: const Color(0xFF2E7D32),
                onTap: _topupWalletDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.approval,
                title: 'Review Outpass',
                subtitle:
                    '${_outpassRequests.where((r) => r.status.contains('Pending')).length} Pending',
                color: const Color(0xFF1E293B),
                onTap: () => setState(() => _currentTab = 1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOutpassApprovalsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Ward Gatepass Approvals',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Approve or decline overnight home visits & outings',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        ..._outpassRequests.map((req) {
          final isPending = req.status.contains('Pending');
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isPending ? Colors.amber.shade400 : Colors.grey.shade200,
                width: isPending ? 1.5 : 1,
              ),
            ),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPending
                              ? Colors.amber.shade100
                              : const Color(0xFFD8F3DC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          req.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isPending
                                ? Colors.amber.shade900
                                : const Color(0xFF1B4332),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '#${req.id}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    req.requestType,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text('Destination: ${req.destination}'),
                  Text('Reason: ${req.reason}'),
                  if (req.parentComment != null)
                    Text('Parent Note: ${req.parentComment}',
                        style: const TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  if (isPending) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2D6A4F),
                        ),
                        onPressed: () => _reviewPassDialog(req),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Review Request'),
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

  Widget _buildFeesAndWalletTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: const Color(0xFF1B4332),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ward Canteen Wallet',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '₹${_ward.canteenBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1B4332),
                  ),
                  onPressed: _topupWalletDialog,
                  child: const Text('Top Up'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Academic & Hostel Fee Statements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        ..._fees.map((fee) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            child: ListTile(
              title: Text(
                fee.title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                  'Due Date: ${fee.dueDate.day}/${fee.dueDate.month}/${fee.dueDate.year}'),
              trailing: fee.isPaid
                  ? const Chip(
                      label: Text('Paid'),
                      backgroundColor: Color(0xFFE8F5E9),
                      labelStyle: TextStyle(
                          color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B4332),
                      ),
                      onPressed: () {
                        _repository.payFee(fee.id);
                        _refreshData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${fee.title} payment successful!'),
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                        );
                      },
                      child: Text('Pay ₹${fee.amount.toStringAsFixed(0)}'),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAcademicsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Attendance & Subject Progress',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Live attendance logs updated by course faculty',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        ..._attendanceList.map((sub) {
          final pct = sub.percentage;
          final pctColor = pct >= 85
              ? const Color(0xFF2E7D32)
              : (pct >= 75 ? Colors.orange : Colors.red);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${sub.subjectCode} - ${sub.subjectName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: pctColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Faculty: ${sub.facultyName} • Attended: ${sub.attendedClasses}/${sub.totalClasses} classes',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: Colors.grey.shade200,
                    color: pctColor,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
