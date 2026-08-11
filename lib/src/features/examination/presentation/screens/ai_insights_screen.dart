import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  final List<Map<String, dynamic>> _atRiskStudents = [
    {
      'roll': '2026CS102',
      'name': 'Sophia Martinez',
      'riskLevel': 'High Risk',
      'reason': 'Declining trend over last 2 semesters (CGPA drop 1.4 points)',
      'recommendedAction':
          'Assign academic advisor & remedial classes in Math III',
    },
    {
      'roll': '2026CS115',
      'name': 'James Wilson',
      'riskLevel': 'Medium Risk',
      'reason': 'Failed 2 internal component tests (CS303 Operating Systems)',
      'recommendedAction':
          'Issue early warning & schedule doubt-solving workshop',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderBanner(isMobile),
              const SizedBox(height: 14),
              _buildAnalyticsSummaryCards(isMobile),
              const SizedBox(height: 16),
              if (isMobile) ...[
                _buildGradeDistributionChartCard(),
                const SizedBox(height: 14),
                _buildAnomalyAlertsCard(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildGradeDistributionChartCard(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildAnomalyAlertsCard()),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _buildAtRiskPredictiveTable(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(bool isMobile) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            const Icon(Icons.psychology, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Exam Insights & Analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Performance optimization, anomaly detection, and early intervention alerts.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSummaryCards(bool isMobile) {
    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          _buildInsightMiniCard(
            'Pass Rate',
            '94.2%',
            '+2.1%',
            Icons.trending_up,
            Colors.green,
          ),
          _buildInsightMiniCard(
            'Mean Score',
            '72.4',
            'Std: 11.2',
            Icons.analytics,
            Colors.blue,
          ),
          _buildInsightMiniCard(
            'Anomalies',
            '03',
            'Moderation',
            Icons.warning_amber,
            Colors.orange,
          ),
          _buildInsightMiniCard(
            'At-Risk',
            '02',
            'Action Req',
            Icons.person_search,
            Colors.red,
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildInsightMiniCard(
          'Overall Pass %',
          '94.2%',
          '+2.1% vs last semester',
          Icons.trending_up,
          Colors.green,
        ),
        const SizedBox(width: 12),
        _buildInsightMiniCard(
          'Mean Score',
          '72.4 / 100',
          'Std Dev: 11.2',
          Icons.analytics,
          Colors.blue,
        ),
        const SizedBox(width: 12),
        _buildInsightMiniCard(
          'Anomalies Flagged',
          '03',
          'Requires Moderation review',
          Icons.warning_amber,
          Colors.orange,
        ),
        const SizedBox(width: 12),
        _buildInsightMiniCard(
          'At-Risk Students',
          '02',
          'Early intervention needed',
          Icons.person_search,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildInsightMiniCard(
    String title,
    String val,
    String sub,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGradeDistributionChartCard() {
    final distribution = [
      {'grade': 'O (Outstanding)', 'percent': 0.25, 'count': '38 Students'},
      {'grade': 'A+ (Excellent)', 'percent': 0.35, 'count': '54 Students'},
      {'grade': 'A (Very Good)', 'percent': 0.20, 'count': '31 Students'},
      {'grade': 'B+ / B (Average)', 'percent': 0.12, 'count': '18 Students'},
      {'grade': 'F / Backlog', 'percent': 0.08, 'count': '12 Students'},
    ];

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
          const Text(
            'Batch Grade Distribution Histogram',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Column(
            children: distribution.map((d) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          d['grade'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          d['count'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: d['percent'] as double,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Colors.grey.shade100,
                      color: AppColors.primary,
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

  Widget _buildAnomalyAlertsCard() {
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
              Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
              SizedBox(width: 6),
              Text(
                'AI Anomaly Signals',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildAnomalyItem(
            'Subject CS302 shows 22% higher failure rate than historical mean. Audit advised.',
            Colors.orange,
          ),
          const Divider(),
          _buildAnomalyItem(
            'Evaluator Prof. K. Patel section has strict marking (-1.8σ). Scaling advised.',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bubble_chart, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtRiskPredictiveTable() {
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
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text(
                'Predictive Failure Risk List',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _atRiskStudents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = _atRiskStudents[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${r['name']} (${r['roll']})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                subtitle: Text(
                  '${r['reason']}\nAction: ${r['recommendedAction']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r['riskLevel'],
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
