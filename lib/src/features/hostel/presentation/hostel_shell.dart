import 'package:flutter/material.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/hostel_models.dart';
import '../data/hostel_repository.dart';
import '../data/mock_hostel_repository.dart';
import 'hostel_complaints_screen.dart';
import 'hostel_gate_scanner_screen.dart';
import 'hostel_inventory_screen.dart';
import 'hostel_mess_screen.dart';
import 'hostel_ops_dashboard_screen.dart';
import 'hostel_outpass_screen.dart';
import 'hostel_room_change_screen.dart';
import 'hostel_student_home_screen.dart';
import 'hostel_vacate_clearance_screen.dart';
import 'hostel_visitors_screen.dart';

class HostelShell extends StatefulWidget {
  const HostelShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.repository,
    this.initialAction,
  });

  final UserSession session;
  final VoidCallback onExitModule;
  final HostelRepository? repository;
  final String? initialAction;

  @override
  State<HostelShell> createState() => _HostelShellState();
}

class _HostelShellState extends State<HostelShell> {
  late final HostelRepository _repository;
  HostelStore? _store;
  String? _error;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        MockHostelRepository(
          studentName: widget.session.displayName,
          studentCode: 'SC2600142',
        );

    _selectedIndex = switch (widget.initialAction) {
      'outpass' => 1,
      'mess' => 2,
      'complaints' => 3,
      'room_change' => 4,
      'visitors' => 5,
      'clearance' => 6,
      _ => 0,
    };

    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final store = await _repository.loadStore();
      if (mounted) {
        setState(() => _store = store);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Hostel services are currently unavailable.');
      }
    }
  }

  void _handleBack() {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    } else {
      widget.onExitModule();
    }
  }

  void _openApplyAccommodationDialog() {
    final typeCtrl = TextEditingController(text: 'Double Sharing');
    final reqCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Apply for Hostel Accommodation',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: 'Double Sharing',
                decoration: const InputDecoration(labelText: 'Preferred Room Type'),
                items: const [
                  DropdownMenuItem(value: 'Single', child: Text('Single Room')),
                  DropdownMenuItem(value: 'Double Sharing', child: Text('Double Sharing')),
                  DropdownMenuItem(value: 'Triple Sharing', child: Text('Triple Sharing')),
                ],
                onChanged: (val) {
                  if (val != null) typeCtrl.text = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reqCtrl,
                decoration: const InputDecoration(
                  labelText: 'Special Requirements (Optional)',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _repository.applyForAccommodation(
                      preferredRoomType: typeCtrl.text,
                      specialRequirements: reqCtrl.text,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _load();
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Hostel Accommodation Application Submitted!')),
                      );
                    }
                  },
                  child: const Text('Submit Application'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final store = _store;
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isStaff = widget.session.role == UserRole.staff ||
        widget.session.role == UserRole.timetableAllocator ||
        widget.session.role == UserRole.admin;

    final pages = [
      if (isStaff)
        HostelOpsDashboardScreen(
          store: store,
          onOpenInventory: () => setState(() => _selectedIndex = 1),
          onOpenOutpasses: () => setState(() => _selectedIndex = 2),
          onOpenComplaints: () => setState(() => _selectedIndex = 3),
          onOpenRoomChanges: () => setState(() => _selectedIndex = 4),
          onOpenClearance: () => setState(() => _selectedIndex = 6),
        )
      else
        HostelStudentHomeScreen(
          store: store,
          onApplyAccommodation: _openApplyAccommodationDialog,
          onOpenOutpass: () => setState(() => _selectedIndex = 1),
          onOpenMess: () => setState(() => _selectedIndex = 2),
          onOpenComplaints: () => setState(() => _selectedIndex = 3),
          onOpenRoomChange: () => setState(() => _selectedIndex = 4),
          onOpenVisitors: () => setState(() => _selectedIndex = 5),
          onOpenVacateClearance: () => setState(() => _selectedIndex = 6),
        ),
      HostelOutpassScreen(
        outpasses: store.outpasses,
        repository: _repository,
        onRefresh: _load,
        onBack: _handleBack,
      ),
      HostelMessScreen(
        messTokens: store.messTokens,
        activeResidency: store.activeResidency,
        repository: _repository,
        onRefresh: _load,
        onBack: _handleBack,
      ),
      HostelComplaintsScreen(
        complaints: store.complaints,
        repository: _repository,
        onRefresh: _load,
        onBack: _handleBack,
      ),
      HostelRoomChangeScreen(
        requests: store.roomChangeRequests,
        repository: _repository,
        onRefresh: _load,
        onBack: _handleBack,
      ),
      HostelVisitorsScreen(
        visitors: store.visitorPasses,
        repository: _repository,
        onRefresh: _load,
        onBack: _handleBack,
      ),
      HostelVacateClearanceScreen(
        clearance: store.clearance,
        activeResidency: store.activeResidency,
        repository: _repository,
        onRefresh: _load,
        onBack: _handleBack,
      ),
      HostelInventoryScreen(
        buildings: store.buildings,
        onBack: _handleBack,
      ),
      HostelGateScannerScreen(
        repository: _repository,
        store: store,
        onRefresh: _load,
        onBack: _handleBack,
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: _selectedIndex == 0
            ? AppBar(
                leading: BackButton(onPressed: _handleBack),
                title: Text(isStaff ? 'Hostel Operations' : 'My Hostel'),
              )
            : null,
        body: Padding(
          padding: const EdgeInsets.only(bottom: 90),
          child: IndexedStack(
            index: _selectedIndex.clamp(0, pages.length - 1),
            children: pages,
          ),
        ),
      ),
    );
  }
}
