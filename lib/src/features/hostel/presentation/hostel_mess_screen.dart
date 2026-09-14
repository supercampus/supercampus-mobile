import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    this.menuEnabled = true,
    this.messEnabled = true,
    this.feeValidFrom,
    this.feeValidUntil,
    this.onBack,
  });

  final List<MessMealToken> messTokens;
  final HostelResidency? activeResidency;
  final HostelRepository repository;
  final VoidCallback onRefresh;
  final bool menuEnabled;
  final bool messEnabled;
  final DateTime? feeValidFrom;
  final DateTime? feeValidUntil;
  final VoidCallback? onBack;

  bool get _hasPaidAccess => feeValidFrom != null && feeValidUntil != null;

  @override
  Widget build(BuildContext context) {
    final isHosteller =
        activeResidency?.residencyStatus == ResidencyStatus.active;
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null ? BackButton(onPressed: onBack) : null,
        title: const Text('Food & meal access'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
          children: [
            _AccessSummary(
              enabled: isHosteller && _hasPaidAccess && messEnabled,
              isHosteller: isHosteller,
              messEnabled: messEnabled,
              validUntil: feeValidUntil,
              room: activeResidency?.roomNumber,
            ),
            const SizedBox(height: 20),
            if (!menuEnabled && !messEnabled)
              const _InfoCard(
                icon: Icons.pause_circle_outline_rounded,
                title: 'Food services are paused',
                subtitle:
                    'Your hostel office will notify you when service resumes.',
              )
            else ...[
              if (menuEnabled) ...[
                const _SectionTitle(
                  title: 'Campus menu',
                  subtitle: 'Browse food and pay only for what you order',
                ),
                const SizedBox(height: 10),
                const _InfoCard(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Menu-based dining',
                  subtitle:
                      'Open the Canteen module to browse live menus, place an order and track pickup.',
                  actionLabel: 'Available in Canteen',
                ),
                const SizedBox(height: 22),
              ],
              if (messEnabled) ...[
                _SectionTitle(
                  title: 'Today’s mess passes',
                  subtitle: _hasPaidAccess
                      ? 'One secure QR for each meal period'
                      : 'Available after hostel fee payment is verified',
                ),
                const SizedBox(height: 10),
                if (!isHosteller)
                  const _InfoCard(
                    icon: Icons.hotel_outlined,
                    title: 'Hosteller access only',
                    subtitle:
                        'Ask the administration to update your residency if this is incorrect.',
                  )
                else if (!_hasPaidAccess)
                  const _InfoCard(
                    icon: Icons.payments_outlined,
                    title: 'Hostel fee verification required',
                    subtitle:
                        'Meal passes appear automatically after the admin or accountant marks your hostel fee as paid.',
                  )
                else if (messTokens.isEmpty)
                  const _InfoCard(
                    icon: Icons.sync_rounded,
                    title: 'Preparing today’s passes',
                    subtitle:
                        'Pull down to refresh. Three passes are issued for every covered day.',
                  )
                else
                  ...messTokens.map((token) => _MealCard(token: token)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AccessSummary extends StatelessWidget {
  const _AccessSummary({
    required this.enabled,
    required this.isHosteller,
    required this.messEnabled,
    required this.validUntil,
    required this.room,
  });
  final bool enabled;
  final bool isHosteller;
  final bool messEnabled;
  final DateTime? validUntil;
  final String? room;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF1D7A46) : AppColors.muted;
    final title = enabled
        ? 'Mess access active'
        : !messEnabled
        ? 'Mess service is off'
        : !isHosteller
        ? 'No active hostel residency'
        : 'Payment verification pending';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              enabled ? Icons.verified_rounded : Icons.lock_outline_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  enabled
                      ? 'Room ${room ?? '—'} · covered until ${_date(validUntil!)}'
                      : 'Access follows residency, paid coverage and campus settings.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.token});
  final MessMealToken token;

  @override
  Widget build(BuildContext context) {
    final used = token.status == MealTokenStatus.used;
    final expired = token.status == MealTokenStatus.expired;
    final enabled = !used && !expired;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: .45)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.primary.withValues(alpha: .1)
                  : AppColors.moduleSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              used ? Icons.check_rounded : Icons.restaurant_rounded,
              color: enabled ? AppColors.primary : AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token.mealType.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  token.mealType.timeWindow,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                if (used && token.redeemedAt != null)
                  Text(
                    'Used at ${_time(token.redeemedAt!)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (enabled)
            FilledButton.tonalIcon(
              onPressed: () => _showQr(context),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Show'),
            )
          else
            Text(
              used ? 'USED' : 'EXPIRED',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  void _showQr(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${token.mealType.label} pass',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Valid ${token.mealType.timeWindow}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: QrImageView(data: token.qrCode, size: 220),
          ),
          const SizedBox(height: 16),
          const Text(
            'Present this pass to the authorised mess scanner. It can be redeemed once.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 8),
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _time(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
}
