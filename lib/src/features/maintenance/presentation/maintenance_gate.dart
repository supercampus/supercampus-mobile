import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/maintenance_repository.dart';

class MaintenanceGate extends StatefulWidget {
  const MaintenanceGate({
    super.key,
    required this.repository,
    required this.loginBuilder,
  });

  final MaintenanceRepository repository;
  final Widget Function() loginBuilder;

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  MaintenanceWindow? _window;
  Timer? _timer;
  bool _administratorAccess = false;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final window = await widget.repository.publicStatus();
      if (!mounted) return;
      setState(() {
        _window = window;
        if (!window.active) _administratorAccess = false;
      });
    } on Object {
      // Fail open here: authentication still has the authoritative server-side
      // lock, while a status-endpoint outage should not replace login with a
      // misleading maintenance message.
      if (mounted && _window == null) {
        setState(() => _window = MaintenanceWindow.inactive);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = _window;
    if (window == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!window.active || _administratorAccess) return widget.loginBuilder();
    final end = window.endsAt;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7FF),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 52,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'SuperCampus is under maintenance',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                window.message.isEmpty
                    ? 'We are making a few improvements. Please check back shortly.'
                    : window.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
              if (end != null) ...[
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5DDF8)),
                  ),
                  child: Text(
                    'Expected back by ${_format(end)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check again'),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _administratorAccess = true),
                child: const Text('Administrator access'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day}/${value.month}/${value.year} at $hour:$minute $period';
  }
}
