import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class DegreeAuditScreen extends StatefulWidget {
  const DegreeAuditScreen({super.key});

  @override
  State<DegreeAuditScreen> createState() => _DegreeAuditScreenState();
}

class _DegreeAuditScreenState extends State<DegreeAuditScreen> {
  final String _searchRoll = '2026CS101';

  final Map<String, dynamic> _auditResult = {
    'roll': '2026CS101',
    'name': 'Alex Johnson',
    'programme': 'B.Tech Computer Science & Engineering',
    'batch': '2022 - 2026',
    'earnedCredits': 164,
    'requiredCredits': 160,
    'cgpa': 9.15,
    'minCgpaReq': 5.00,
    'mandatoryPassed': true,
    'electivesPassed': true,
    'disciplinaryClearance': true,
    'feeClearance': true,
    'eligibilityDecision': 'FULLY ELIGIBLE FOR DEGREE CONFERRAL',
  };

  @override
  Widget build(BuildContext context) {
    final earned = _auditResult['earnedCredits'] as int;
    final requiredC = _auditResult['requiredCredits'] as int;
    final progress = (earned / requiredC).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchHeader(isMobile),
              const SizedBox(height: 14),
              _buildDecisionBanner(isMobile),
              const SizedBox(height: 14),
              if (isMobile) ...[
                _buildCreditProgressCard(earned, requiredC, progress, isMobile),
                const SizedBox(height: 14),
                _buildRequirementsChecklist(isMobile),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildRequirementsChecklist(isMobile),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: _buildCreditProgressCard(
                        earned,
                        requiredC,
                        progress,
                        isMobile,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchHeader(bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.school, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  'Degree Audit Gatekeeper',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Enter Roll No (e.g. 2026CS101)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.school, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automated Degree Audit Gatekeeper',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Verify academic progress, mandatory/elective credits, CGPA threshold, and clearance holds.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 250,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Enter Roll No (e.g. 2026CS101)',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionBanner(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.green, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _auditResult['eligibilityDecision'],
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${_auditResult['name']} ($_searchRoll)',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsChecklist(bool isMobile) {
    final checks = [
      {
        'title': 'Mandatory Core Courses',
        'desc': 'All core subject credits earned (120/120)',
        'status': true,
      },
      {
        'title': 'Elective Requirement',
        'desc': 'Minimum elective credits earned (44/40)',
        'status': true,
      },
      {
        'title': 'Total Credits Threshold',
        'desc': 'Total credits >= Minimum (164/160)',
        'status': true,
      },
      {
        'title': 'Minimum CGPA Check',
        'desc': 'CGPA >= 5.00 Threshold (Current: 9.15)',
        'status': true,
      },
      {
        'title': 'Disciplinary Clearance',
        'desc': 'No active disciplinary holds on record',
        'status': true,
      },
      {
        'title': 'Fee Clearance Check',
        'desc': 'All institutional dues cleared',
        'status': true,
      },
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audit Component Verification',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: checks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final c = checks[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  (c['status'] as bool) ? Icons.check_circle : Icons.cancel,
                  color: (c['status'] as bool) ? Colors.green : Colors.red,
                  size: 18,
                ),
                title: Text(
                  c['title'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                subtitle: Text(
                  c['desc'] as String,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreditProgressCard(
    int earned,
    int req,
    double progress,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Programme Credit Progress',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: isMobile ? 110 : 130,
                  height: isMobile ? 110 : 130,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$earned / $req',
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Credits',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Academic CGPA Overview',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (_auditResult['cgpa'] as double) / 10.0,
            backgroundColor: Colors.grey.shade200,
            color: Colors.green,
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          Text(
            'CGPA: ${_auditResult['cgpa']} / 10.00',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
