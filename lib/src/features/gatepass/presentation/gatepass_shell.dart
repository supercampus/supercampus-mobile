import 'package:flutter/material.dart';

import '../../authentication/data/auth_repository.dart';
import '../data/gatepass_models.dart';
import '../data/gatepass_repository.dart';
import '../data/mock_gatepass_repository.dart';
import 'apply_outpass_sheet.dart';
import 'gatepass_access_screen.dart';
import 'gatepass_dashboard_screen.dart';
import 'gatepass_requests_screen.dart';
import 'gatepass_visitors_screen.dart';

class GatepassShell extends StatefulWidget {
  const GatepassShell({
    super.key,
    required this.session,
    required this.onExitModule,
    this.repository,
    this.initialAction,
  });

  final StudentSession session;
  final VoidCallback onExitModule;
  final GatepassRepository? repository;
  final String? initialAction;

  @override
  State<GatepassShell> createState() => _GatepassShellState();
}

class _GatepassShellState extends State<GatepassShell> {
  late final GatepassRepository _repository;
  GatepassStore? _store;
  String? _error;
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        MockGatepassRepository(
          studentName: widget.session.displayName,
          email: widget.session.email,
        );
    _selectedIndex = switch (widget.initialAction) {
      'visitors' => 2,
      'access' => 3,
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
        if (widget.initialAction == 'outpass') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openApply();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Gatepass services are unavailable.');
      }
    }
  }

  Future<GatepassRequest> _submitRequest(GatepassRequestDraft draft) async {
    final request = await _repository.submitRequest(draft);
    if (mounted) {
      setState(() {
        _store = _store!.copyWith(requests: [request, ..._store!.requests]);
      });
    }
    return request;
  }

  Future<VisitorInvitation> _inviteVisitor(VisitorInvitationDraft draft) async {
    final visitor = await _repository.inviteVisitor(draft);
    if (mounted) {
      setState(() {
        _store = _store!.copyWith(visitors: [visitor, ..._store!.visitors]);
      });
    }
    return visitor;
  }

  Future<void> _cancelRequest(GatepassRequest request) async {
    try {
      final cancelled = await _repository.cancelRequest(request.id);
      if (!mounted) return;
      final requests = _store!.requests
          .map((item) => item.id == cancelled.id ? cancelled : item)
          .toList();
      setState(() => _store = _store!.copyWith(requests: requests));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outpass request cancelled.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openApply() async {
    final request = await showModalBottomSheet<GatepassRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.96,
        child: ApplyOutpassSheet(onSubmit: _submitRequest),
      ),
    );
    if (request == null || !mounted) return;
    setState(() => _selectedIndex = 1);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${request.id} sent for approval.')));
  }

  Future<void> _openInvite() async {
    final visitor = await showModalBottomSheet<VisitorInvitation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.93,
        child: InviteVisitorSheet(onSubmit: _inviteVisitor),
      ),
    );
    if (visitor == null || !mounted) return;
    setState(() => _selectedIndex = 2);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${visitor.id} sent for review.')));
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

    final pages = [
      GatepassDashboardScreen(
        store: store,
        onApplyOutpass: _openApply,
        onOpenAccess: () => setState(() => _selectedIndex = 3),
        onOpenRequests: () => setState(() => _selectedIndex = 1),
        onInviteVisitor: _openInvite,
        onExitModule: widget.onExitModule,
      ),
      GatepassRequestsScreen(
        requests: store.requests,
        workflow: store.workflow,
        onApply: _openApply,
        onCancel: _cancelRequest,
      ),
      GatepassVisitorsScreen(visitors: store.visitors, onInvite: _openInvite),
      GatepassAccessScreen(store: store),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
    );
  }
}
