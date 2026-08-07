import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class NotificationsAlertsScreen extends StatefulWidget {
  const NotificationsAlertsScreen({super.key});

  @override
  State<NotificationsAlertsScreen> createState() => _NotificationsAlertsScreenState();
}

class _NotificationsAlertsScreenState extends State<NotificationsAlertsScreen> {
  final List<Map<String, dynamic>> _events = [
    {
      'code': 'exam.schedule_published',
      'title': 'Exam Schedule Published',
      'recipients': 'Students, Faculty, Parents',
      'channels': 'Portal, Email, Push',
      'active': true,
    },
    {
      'code': 'exam.eligibility_changed',
      'title': 'Student Eligibility Changed',
      'recipients': 'Student, Advisor, Exam Office',
      'channels': 'Portal, Email',
      'active': true,
    },
    {
      'code': 'exam.hall_ticket_ready',
      'title': 'Hall Ticket Generated',
      'recipients': 'Student',
      'channels': 'Portal, Push',
      'active': true,
    },
    {
      'code': 'marks.submitted_for_verification',
      'title': 'Marks Submitted for Verification',
      'recipients': 'HoD, Exam Officer',
      'channels': 'Portal, Email',
      'active': true,
    },
    {
      'code': 'result.published',
      'title': 'End-Sem Result Published',
      'recipients': 'Student, Parent, Advisor',
      'channels': 'Portal, Email, Push',
      'active': true,
    },
  ];

  final List<Map<String, dynamic>> _logs = [
    {
      'event': 'result.published',
      'recipient': 'Alex Johnson (Student)',
      'channel': 'Push Notification',
      'status': 'Delivered',
      'time': '10 mins ago',
    },
    {
      'event': 'exam.hall_ticket_ready',
      'recipient': 'Alex Johnson (Student)',
      'channel': 'Email (student@supercampus.edu)',
      'status': 'Sent',
      'time': '1 hour ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderBanner(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildEventRulesPanel()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildDeliveryLogsPanel()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Event-Driven Exam Notifications & Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Automated alerts dispatched across Portal, Mobile Push, and Email channels.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRulesPanel() {
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
          const Text('Configured Notification Rules', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _events.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ev = _events[index];
              return ListTile(
                dense: true,
                title: Text(ev['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Recipients: ${ev['recipients']}\nChannels: ${ev['channels']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                trailing: Switch(
                  value: ev['active'],
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) {
                    setState(() => ev['active'] = val);
                    // TODO: Toggle notification rule POST /api/v1/examination/notifications/rule
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryLogsPanel() {
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
          const Text('Recent Dispatch Audit Log', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _logs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = _logs[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.send_outlined, size: 16, color: Colors.blue),
                title: Text(log['event'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                subtitle: Text('${log['recipient']} • ${log['channel']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                trailing: Text(log['time'], style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              );
            },
          ),
        ],
      ),
    );
  }
}
