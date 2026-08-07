import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Canonical examination statuses as per specification Section 22.
enum ExamCanonicalStatus {
  draft('Draft', 'Initial creation, incomplete config', Colors.grey),
  configured('Configured', 'Parameters set, pending approval', Colors.blue),
  approved('Approved', 'Configuration validated & approved', Colors.indigo),
  scheduled('Scheduled', 'Dates, halls & invigilators assigned', Colors.teal),
  published('Published', 'Schedule visible to students', Colors.cyan),
  conducted('Conducted', 'Exam completed, scripts collected', Colors.amber),
  marksSubmitted('Marks Submitted', 'Faculty submitted marks', Colors.orange),
  verified('Verified', 'Department verification complete', Colors.deepOrange),
  moderated('Moderated', 'Moderation rules applied', Colors.purple),
  locked('Locked', 'Marks frozen, immutable state', Colors.blueGrey),
  resultApproved('Result Approved', 'Grades & GPA calculated', Colors.lightGreen),
  resultPublished('Result Published', 'Results live for students', Colors.green),
  revaluation('Revaluation', 'Revaluation active', Colors.pink),
  closed('Closed', 'Cycle complete & archived', Colors.brown);

  const ExamCanonicalStatus(this.label, this.description, this.color);
  final String label;
  final String description;
  final Color color;
}

class StatusLifecycleWidget extends StatelessWidget {
  const StatusLifecycleWidget({
    super.key,
    required this.currentStatus,
    this.onStatusSelected,
  });

  final ExamCanonicalStatus currentStatus;
  final ValueChanged<ExamCanonicalStatus>? onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ExamCanonicalStatus.values.indexOf(currentStatus);

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
              const Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Canonical Examination Status Lifecycle',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: currentStatus.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentStatus.color),
                ),
                child: Text(
                  currentStatus.label,
                  style: TextStyle(
                    color: currentStatus.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentStatus.description,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(ExamCanonicalStatus.values.length, (index) {
                final status = ExamCanonicalStatus.values[index];
                final isPassed = index <= currentIndex;
                final isCurrent = index == currentIndex;

                return InkWell(
                  onTap: () {
                    if (onStatusSelected != null) {
                      onStatusSelected!(status);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? status.color
                          : isPassed
                              ? status.color.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? status.color : (isPassed ? status.color : Colors.grey.shade300),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCurrent
                              ? Icons.play_circle_fill
                              : isPassed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                          size: 14,
                          color: isCurrent
                              ? Colors.white
                              : isPassed
                                  ? status.color
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent
                                ? Colors.white
                                : isPassed
                                    ? AppColors.ink
                                    : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
