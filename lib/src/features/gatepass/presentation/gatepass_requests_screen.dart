import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../data/gatepass_models.dart';
import 'widgets/gatepass_ui.dart';

class GatepassRequestsScreen extends StatelessWidget {
  const GatepassRequestsScreen({
    super.key,
    required this.requests,
    required this.residency,
    required this.onApplyLeavePass,
    required this.onApplyOutpass,
    required this.onCancel,
  });

  final List<GatepassRequest> requests;
  final StudentResidency residency;
  final VoidCallback onApplyLeavePass;
  final VoidCallback onApplyOutpass;
  final Future<void> Function(GatepassRequest request) onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              GatepassPageHeader(
                title: 'Pass history',
                subtitle: 'Track your leave and outpass requests',
                trailing: PopupMenuButton<GatepassPassKind>(
                  tooltip: 'Apply for a pass',
                  onSelected: (kind) => kind == GatepassPassKind.leavePass
                      ? onApplyLeavePass()
                      : onApplyOutpass(),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: GatepassPassKind.leavePass,
                      child: Text('Apply leave pass'),
                    ),
                    if (residency == StudentResidency.hosteller)
                      const PopupMenuItem(
                        value: GatepassPassKind.outpass,
                        child: Text('Apply hostel outpass'),
                      ),
                  ],
                  icon: const Icon(
                    Icons.add_circle,
                    color: AppColors.gateBlue,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (requests.isEmpty)
                const GatepassSurface(
                  padding: EdgeInsets.symmetric(vertical: 42, horizontal: 20),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined, size: 36),
                      SizedBox(height: 10),
                      Text('No leave pass or outpass requests yet'),
                    ],
                  ),
                )
              else
                for (final request in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RequestCard(request: request, onCancel: onCancel),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onCancel});

  final GatepassRequest request;
  final Future<void> Function(GatepassRequest request) onCancel;

  @override
  Widget build(BuildContext context) {
    final qrPayload = request.qrPayload;
    final code = qrPayload == null
        ? null
        : _sixDigitCode(request.manualCode, qrPayload);
    return GatepassSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.passKind.label} • ${request.type.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ApprovalPill(status: request.status),
            ],
          ),
          const SizedBox(height: 7),
          Text(request.destination),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.logout, size: 18, color: AppColors.gateBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatShortDate(request.departureAt)}, ${formatTime(request.departureAt)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.login, size: 18, color: AppColors.gateMagenta),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatShortDate(request.returnAt)}, ${formatTime(request.returnAt)}',
                ),
              ),
            ],
          ),
          if (request.approver != null) ...[
            const SizedBox(height: 12),
            Text('Reviewed by ${request.approver}'),
          ],
          if (request.reviewNote != null) ...[
            const SizedBox(height: 8),
            Text(
              request.reviewNote!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (request.status == ApprovalStatus.rejected) ...[
            const SizedBox(height: 8),
            Text(
              request.workflowState == 'rejected'
                  ? 'This request was rejected by an approver.'
                  : 'This request was rejected.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (request.status == ApprovalStatus.pending) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onCancel(request),
                child: const Text('Cancel request'),
              ),
            ),
          ],
          if (request.status == ApprovalStatus.approved &&
              qrPayload != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF087A4B),
                        size: 28,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Gate access ready',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Show this QR at security. Tap it to open full screen.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  children: [
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: const ValueKey('request-qr-open'),
                        onTap: () =>
                            _openFullScreenQr(context, qrPayload, code!),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: QrImageView(
                            data: qrPayload,
                            size: 112,
                            padding: EdgeInsets.zero,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.circle,
                              color: Color(0xFF151419),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.circle,
                              color: Color(0xFF151419),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      code!,
                      key: const ValueKey('request-qr-code'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _sixDigitCode(String? manualCode, String payload) {
    final supplied = (manualCode ?? '').replaceAll(RegExp(r'\D'), '');
    if (supplied.isNotEmpty) {
      return supplied.length >= 6
          ? supplied.substring(supplied.length - 6)
          : supplied.padLeft(6, '0');
    }
    final digits = payload.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) return digits.substring(digits.length - 6);
    var hash = 0;
    for (final unit in payload.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return (hash % 1000000).toString().padLeft(6, '0');
  }

  void _openFullScreenQr(BuildContext context, String payload, String code) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _RequestQrScreen(payload: payload, code: code),
      ),
    );
  }
}

class _RequestQrScreen extends StatelessWidget {
  const _RequestQrScreen({required this.payload, required this.code});

  final String payload;
  final String code;

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width - 72).clamp(230.0, 340.0);
    return Scaffold(
      backgroundColor: const Color(0xFF111014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111014),
        foregroundColor: Colors.white,
        title: const Text('Gatepass QR'),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: payload,
                    size: size,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Color(0xFF151419),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF151419),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  code,
                  key: const ValueKey('fullscreen-request-qr-code'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Present this gatepass at security',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
