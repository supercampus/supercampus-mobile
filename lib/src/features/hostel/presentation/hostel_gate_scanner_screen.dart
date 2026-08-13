import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';

class HostelGateScannerScreen extends StatefulWidget {
  const HostelGateScannerScreen({
    super.key,
    required this.repository,
    required this.store,
    required this.onRefresh,
    this.onBack,
  });

  final HostelRepository repository;
  final HostelStore store;
  final VoidCallback onRefresh;
  final VoidCallback? onBack;

  @override
  State<HostelGateScannerScreen> createState() => _HostelGateScannerScreenState();
}

class _HostelGateScannerScreenState extends State<HostelGateScannerScreen> {
  String? _scanResult;
  bool _isSuccess = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null ? BackButton(onPressed: widget.onBack) : null,
        title: const Text('Hostel Gate & Mess QR Scanner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Simulated Camera Finder Window
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF070907),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white54, size: 80),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.amber, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const Positioned(
                    bottom: 12,
                    child: Text(
                      'Position Outpass / Mess QR inside frame',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Scan Shortcuts
            Text(
              'Simulate Gate / Mess Scanning',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (widget.store.outpasses.isEmpty) return;
                      final out = widget.store.outpasses.first;
                      final mov = await widget.repository.scanOutpassGate(
                        outpassId: out.id,
                        gateName: 'Hostel Main Gate',
                        action: 'EXIT',
                      );
                      widget.onRefresh();
                      setState(() {
                        _isSuccess = true;
                        _scanResult = 'VALID OUTPASS EXIT!\n${mov.studentName} (${out.id})\nStatus: OUTSIDE HOSTEL';
                      });
                    },
                    icon: const Icon(Icons.north_east),
                    label: const Text('Scan Exit Outpass'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (widget.store.outpasses.isEmpty) return;
                      final out = widget.store.outpasses.first;
                      final mov = await widget.repository.scanOutpassGate(
                        outpassId: out.id,
                        gateName: 'Hostel Main Gate',
                        action: 'ENTRY',
                      );
                      widget.onRefresh();
                      setState(() {
                        _isSuccess = true;
                        _scanResult = 'VALID RETURN RECORDED!\n${mov.studentName} (${out.id})\nStatus: INSIDE HOSTEL';
                      });
                    },
                    icon: const Icon(Icons.south_west),
                    label: const Text('Scan Return'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                ),
                onPressed: () async {
                  if (widget.store.messTokens.isEmpty) return;
                  final token = widget.store.messTokens.firstWhere(
                    (t) => t.status == MealTokenStatus.unused,
                    orElse: () => widget.store.messTokens.first,
                  );
                  await widget.repository.redeemMessMeal(token.id);
                  widget.onRefresh();
                  setState(() {
                    _isSuccess = true;
                    _scanResult = 'MESS MEAL GRANTED!\n${token.studentName} - ${token.mealType.label}\nStatus: MEAL SERVED & TOKEN REDEEMED';
                  });
                },
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Scan Mess Meal Token'),
              ),
            ),

            if (_scanResult != null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.cancel,
                      color: _isSuccess ? Colors.green.shade800 : Colors.red.shade800,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _scanResult!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
