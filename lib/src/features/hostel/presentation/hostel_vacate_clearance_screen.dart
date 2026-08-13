import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

class HostelVacateClearanceScreen extends StatefulWidget {
  const HostelVacateClearanceScreen({
    super.key,
    required this.clearance,
    required this.activeResidency,
    required this.repository,
    required this.onRefresh,
    this.onBack,
  });

  final HostelClearance? clearance;
  final HostelResidency? activeResidency;
  final HostelRepository repository;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  @override
  State<HostelVacateClearanceScreen> createState() =>
      _HostelVacateClearanceScreenState();
}

class _HostelVacateClearanceScreenState
    extends State<HostelVacateClearanceScreen> {
  late bool roomCleared;
  late bool assetsReturned;
  late bool keyReturned;
  late bool feesPaid;
  late bool messCleared;
  late bool complaintsClosed;
  late bool damageSettled;

  @override
  void initState() {
    super.initState();
    final c = widget.clearance;
    roomCleared = c?.roomCleared ?? false;
    assetsReturned = c?.assetsReturned ?? false;
    keyReturned = c?.keyReturned ?? false;
    feesPaid = c?.feesPaid ?? true;
    messCleared = c?.messCleared ?? true;
    complaintsClosed = c?.complaintsClosed ?? true;
    damageSettled = c?.damageSettled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final residency = widget.activeResidency;

    if (residency == null) {
      return Scaffold(
        appBar: AppBar(
          leading: widget.onBack != null ? BackButton(onPressed: widget.onBack) : null,
          title: const Text('Vacating & Hostel Clearance'),
        ),
        body: const Center(child: Text('No residency record found.')),
      );
    }

    final isCompleted = residency.residencyStatus == ResidencyStatus.completed;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null ? BackButton(onPressed: widget.onBack) : null,
        title: const Text('Vacating & 7-Point Clearance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.grey.shade100 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCompleted ? Colors.grey.shade300 : Colors.blue.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.assignment_turned_in,
                    color: isCompleted ? Colors.grey.shade700 : Colors.blue.shade800,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCompleted
                              ? 'RESIDENCY CLOSED & CHECKED-OUT'
                              : 'HOSTEL VACATING & CLEARANCE FLOW',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCompleted
                                ? Colors.grey.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          'Student: ${residency.studentName} (${residency.studentCode})\nRoom: ${residency.hostelName} · ${residency.roomNumber}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Check-In vs Check-Out Room Asset Baseline Inspector
            Text(
              'Room Assets & Condition Baseline Comparison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildAssetInspectionTable(context),

            const SizedBox(height: 24),

            // 7-Point Clearance Checklist
            Text(
              '7-Point Mandatory Clearance Checklist',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Every item must be verified before final check-out can be recorded.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildChecklistTile('1. Room Cleared & Cleaned', roomCleared, (v) {
              setState(() => roomCleared = v!);
            }),
            _buildChecklistTile('2. Room Assets Issued Returned', assetsReturned, (v) {
              setState(() => assetsReturned = v!);
            }),
            _buildChecklistTile('3. Room Key Handed Back', keyReturned, (v) {
              setState(() => keyReturned = v!);
            }),
            _buildChecklistTile('4. Hostel Dues & Fees Paid', feesPaid, (v) {
              setState(() => feesPaid = v!);
            }),
            _buildChecklistTile('5. Mess Dues Cleared', messCleared, (v) {
              setState(() => messCleared = v!);
            }),
            _buildChecklistTile('6. Maintenance Complaints Closed', complaintsClosed, (v) {
              setState(() => complaintsClosed = v!);
            }),
            _buildChecklistTile('7. Damage Assessment Charges Settled', damageSettled, (v) {
              setState(() => damageSettled = v!);
            }),

            const SizedBox(height: 24),

            // Final Action Buttons
            if (!isCompleted) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await widget.repository.updateClearanceChecklist(
                      clearanceId: widget.clearance?.id ?? 'CLR_01',
                      roomCleared: roomCleared,
                      assetsReturned: assetsReturned,
                      keyReturned: keyReturned,
                      feesPaid: feesPaid,
                      messCleared: messCleared,
                      complaintsClosed: complaintsClosed,
                      damageSettled: damageSettled,
                    );
                    widget.onRefresh();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Clearance Checklist updated.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Update Clearance Checklist'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await widget.repository.completeCheckout(residency.id);
                    widget.onRefresh();
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Final Check-Out Recorded! Hostel Residency CLOSED & Bed Released for Cleaning.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Execute Final Check-Out & Release Bed'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssetInspectionTable(BuildContext context) {
    final assets = [
      {'asset': 'Bed & Mattress', 'checkin': 'Good', 'checkout': 'Good', 'status': 'OK'},
      {'asset': 'Study Table', 'checkin': 'Good', 'checkout': 'Good', 'status': 'OK'},
      {'asset': 'Wooden Chair', 'checkin': 'Good', 'checkout': 'Minor Scratch', 'status': 'OK'},
      {'asset': 'Cupboard & Key', 'checkin': 'Issued', 'checkout': 'Returned', 'status': 'OK'},
      {'asset': 'Ceiling Fan & Light', 'checkin': 'Working', 'checkout': 'Working', 'status': 'OK'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Table(
        border: TableBorder.symmetric(inside: const BorderSide(color: AppColors.border)),
        children: [
          const TableRow(
            decoration: BoxDecoration(color: AppColors.canvas),
            children: [
              Padding(padding: EdgeInsets.all(8), child: Text('Asset Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Check-In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Check-Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Padding(padding: EdgeInsets.all(8), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
          ...assets.map((item) {
            return TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text(item['asset']!, style: const TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(8), child: Text(item['checkin']!, style: const TextStyle(fontSize: 12))),
                Padding(padding: const EdgeInsets.all(8), child: Text(item['checkout']!, style: const TextStyle(fontSize: 12))),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    item['status']!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChecklistTile(String label, bool value, ValueChanged<bool?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: value ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? Colors.green.shade300 : AppColors.border,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: value ? Colors.green.shade900 : AppColors.ink,
          ),
        ),
        activeColor: Colors.green.shade700,
        dense: true,
      ),
    );
  }
}
