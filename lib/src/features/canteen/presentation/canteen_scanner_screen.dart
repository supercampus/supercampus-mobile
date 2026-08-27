import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../scanner/presentation/scan_qr_screen.dart';

class CanteenScannerScreen extends StatelessWidget {
  const CanteenScannerScreen({super.key, required this.onScan});

  final Future<void> Function(String payload) onScan;

  Future<void> _scan(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final payload = await openScanQr(context, title: 'Scan pickup QR');
    if (payload == null || !context.mounted) return;
    try {
      await onScan(payload);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Order collected successfully.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF070907),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Scan counter QR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.flash_off, color: Colors.white),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: SizedBox.square(
                      dimension: 280,
                      child: CustomPaint(painter: _ScannerFramePainter()),
                    ),
                  ),
                  const SizedBox(height: 34),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.center_focus_strong, color: Colors.white70),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Position the canteen QR inside the frame',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      minimumSize: const Size(0, 50),
                    ),
                    onPressed: () => _scan(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan pickup QR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.amber
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const corner = 42.0;
    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, corner)
      ..moveTo(size.width, size.height - corner)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - corner, size.height)
      ..moveTo(corner, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, size.height - corner);
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(18, size.height / 2),
      Offset(size.width - 18, size.height / 2),
      paint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
