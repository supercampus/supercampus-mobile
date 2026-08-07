import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ExamConductScreen extends StatefulWidget {
  const ExamConductScreen({super.key});

  @override
  State<ExamConductScreen> createState() => _ExamConductScreenState();
}

class _ExamConductScreenState extends State<ExamConductScreen> {
  final List<Map<String, dynamic>> _checklist = [
    {'step': '1', 'action': 'Seal question papers & verification envelope', 'verifiedBy': 'Examination Controller', 'done': true},
    {'step': '2', 'action': 'Verify digital exam assets encryption & keys', 'verifiedBy': 'IT Admin', 'done': true},
    {'step': '3', 'action': 'Confirm hall readiness (seating, CCTV, power)', 'verifiedBy': 'Facilities', 'done': true},
    {'step': '4', 'action': 'Distribute invigilator briefing & duty roster', 'verifiedBy': 'Examination Admin', 'done': true},
    {'step': '5', 'action': 'Activate QR ID / Hall Ticket verification system', 'verifiedBy': 'Hall Supervisor', 'done': true},
    {'step': '6', 'action': 'Enable incident reporting live channel', 'verifiedBy': 'Examination Admin', 'done': true},
  ];

  final List<Map<String, dynamic>> _incidents = [
    {
      'id': 'INC-101',
      'hall': 'Auditorium Hall A',
      'student': '2026CS108 (Mark Davis)',
      'severity': 'Critical',
      'type': 'Malpractice / Unauthorized Material',
      'action': 'Isolated, paper confiscated, evidence logged',
      'time': '10:15 AM',
    },
    {
      'id': 'INC-102',
      'hall': 'Exam Block Room 204',
      'student': '2026CS112 (Elena Rostova)',
      'severity': 'Medium',
      'type': 'Medical Consideration',
      'action': 'First aid provided, granted 15 mins compensation',
      'time': '11:05 AM',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPreExamChecklist(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildAttendanceRosterPanel()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildIncidentReportPanel()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreExamChecklist() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Pre-Exam Secure Release Verification Checklist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () {
                  // TODO: Submit pre-exam readiness check POST /api/v1/examination/conduct/pre-check
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Secure release verified. Hall session is now LIVE.')),
                  );
                },
                icon: const Icon(Icons.lock_open, size: 16),
                label: const Text('Unlock Exam Session'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _checklist.map((c) {
              return Container(
                width: 320,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: c['done'],
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => c['done'] = val!),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['action'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Text('By: ${c['verifiedBy']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRosterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_reg, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Live Hall Attendance & Desk Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              Chip(
                label: const Text('142 / 150 Present'),
                backgroundColor: Colors.green.withValues(alpha: 0.12),
                side: BorderSide.none,
                labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 20)),
            title: const Text('Scan Student QR / Hall Ticket'),
            subtitle: const Text('Tap to open camera barcode scanner'),
            trailing: OutlinedButton(
              onPressed: () {
                // TODO: Open QR scanner sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulated QR scan: Student 2026CS101 verified at Desk A-14.')),
                );
              },
              child: const Text('Scan Ticket'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentReportPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_gmailerrorred, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text('Incident & Malpractice Logs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.red),
                tooltip: 'Report New Incident',
                onPressed: () => _showReportIncidentDialog(context),
              ),
            ],
          ),
          const Divider(),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _incidents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final inc = _incidents[index];
              return ListTile(
                dense: true,
                title: Text('${inc['id']} • ${inc['type']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                subtitle: Text('${inc['student']} (${inc['hall']}) • ${inc['action']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(inc['severity'], style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showReportIncidentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Examination Incident / Malpractice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Student Roll No / Hall Ticket ID')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: 'Critical',
              decoration: const InputDecoration(labelText: 'Severity Level'),
              items: ['Critical', 'High', 'Medium', 'Low'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 10),
            const TextField(
              decoration: InputDecoration(labelText: 'Incident Description & Action Taken'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // TODO: Log incident POST /api/v1/examination/conduct/incident
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Incident logged and sent to Controller Office.')),
              );
            },
            child: const Text('Submit Incident Report'),
          ),
        ],
      ),
    );
  }
}
