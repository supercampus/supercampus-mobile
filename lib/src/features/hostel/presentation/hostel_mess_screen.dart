import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

class HostelMessScreen extends StatelessWidget {
  const HostelMessScreen({
    super.key,
    required this.messTokens,
    required this.activeResidency,
    required this.repository,
    required this.onRefresh,
    this.onBack,
  });

  final List<MessMealToken> messTokens;
  final HostelResidency? activeResidency;
  final HostelRepository repository;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isHosteller = activeResidency != null &&
        activeResidency!.residencyStatus == ResidencyStatus.active;

    return Scaffold(
      appBar: AppBar(
        leading: onBack != null ? BackButton(onPressed: onBack) : null,
        title: const Text('Hostel Mess & Meal Access'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eligibility Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isHosteller ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHosteller ? Colors.green.shade300 : Colors.red.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isHosteller ? Icons.verified_user : Icons.gpp_bad,
                    color: isHosteller ? Colors.green.shade800 : Colors.red.shade800,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHosteller
                              ? 'MESS ACCESS ENABLED'
                              : 'NOT ELIGIBLE FOR HOSTEL MESS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isHosteller
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                        Text(
                          isHosteller
                              ? 'Active Hostel Residency Verified (${activeResidency!.hostelName} · Room ${activeResidency!.roomNumber})'
                              : 'Hostel mess meal QR tokens are reserved strictly for active hostel residents.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isHosteller
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (isHosteller) ...[
              const SizedBox(height: 20),
              Text(
                'Today\'s Meal QR Tokens',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'One meal QR = One meal access. Each QR token is valid only during its meal period.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // 3 Meal QR Token Cards
              ...messTokens.map((token) => _buildMealTokenCard(context, token)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealTokenCard(BuildContext context, MessMealToken token) {
    final isUsed = token.status == MealTokenStatus.used;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUsed ? AppColors.border : AppColors.primary,
          width: isUsed ? 1 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUsed
                  ? Colors.grey.shade100
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUsed ? Icons.check_circle_outline : Icons.restaurant_rounded,
              color: isUsed ? Colors.grey : AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.mealType.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUsed ? AppColors.muted : AppColors.ink,
                  ),
                ),
                Text(
                  'Valid: ${token.mealType.timeWindow}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (isUsed && token.redeemedAt != null)
                  Text(
                    'Redeemed at ${token.redeemedAt!.hour}:${token.redeemedAt!.minute.toString().padLeft(2, '0')} PM',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          if (!isUsed)
            FilledButton.icon(
              onPressed: () => _openRedeemDialog(context, token),
              icon: const Icon(Icons.qr_code_2, size: 16),
              label: const Text('Show QR', style: TextStyle(fontSize: 12)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'USED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openRedeemDialog(BuildContext context, MessMealToken token) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${token.mealType.label.toUpperCase()} MEAL QR TOKEN',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 170,
                height: 170,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Icon(Icons.qr_code_2, size: 130, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                token.studentName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Text(
                'Show this QR token to mess staff scanner',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await repository.redeemMessMeal(token.id);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${token.mealType.label} QR Marked as REDEEMED!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Simulate Mess Scanner Scan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
