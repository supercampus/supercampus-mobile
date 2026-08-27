import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/widgets/module_navigation_buttons.dart';
import '../../../core/widgets/skeleton_loading.dart';
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

/// How far the device must move before the app re-asks the API which side of
/// the fence it is on. Small enough to catch walking through the gate, large
/// enough that GPS jitter while sitting still does not rotate the pass.
const _zoneCheckDistanceMetres = 25;

class _GatepassShellState extends State<GatepassShell> {
  late final GatepassRepository _repository;
  GatepassStore? _store;
  String? _error;
  var _selectedIndex = 0;
  StreamSubscription<Position>? _positionSubscription;
  var _receivedPositionBaseline = false;
  var _loadInFlight = false;
  var _loadQueued = false;

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
    if (widget.repository != null) _startWatching();
  }

  /// Crossing the campus boundary is the only automatic refresh trigger. Each
  /// activation rotates the token server-side, so a time-based refresh would
  /// repeatedly invalidate a QR while its owner is standing still.
  void _startWatching() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _zoneCheckDistanceMetres,
          ),
        ).listen(
          (_) {
            // Android commonly emits the current fix as soon as a listener is
            // attached. The initial load already used that fix, so consuming it
            // again would rotate the newly rendered QR immediately.
            if (!_receivedPositionBaseline) {
              _receivedPositionBaseline = true;
              return;
            }
            unawaited(_load(silent: true));
          },
          // Permission can be revoked or location switched off mid-session.
          // Keep the last verified screen instead of replacing it with an error.
          onError: (_) {},
        );
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    // Location and timer events can arrive together. Serializing activation is
    // important because every successful request rotates the server-side QR;
    // overlapping requests could otherwise leave the UI showing the token
    // invalidated by the request that finished just before it.
    if (_loadInFlight) {
      _loadQueued = true;
      return;
    }
    _loadInFlight = true;
    if (!silent) setState(() => _error = null);
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
    } on GatepassException catch (error) {
      // The repository already words its failures for the reader; replacing
      // them with "unavailable" throws away the one sentence that says what to
      // do about it.
      if (mounted && !silent) setState(() => _error = error.message);
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _error = 'Gatepass services are unavailable.');
      }
    } finally {
      _loadInFlight = false;
      if (_loadQueued && mounted) {
        _loadQueued = false;
        unawaited(_load(silent: true));
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

  void _handleBack() {
    if (_selectedIndex == 0) {
      widget.onExitModule();
      return;
    }
    setState(() => _selectedIndex = 0);
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
      return const Scaffold(body: SkeletonList(rows: 5, rowHeight: 88));
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

    const titles = ['Gatepass', 'Requests', 'Visitors', 'Gate access'];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: _selectedIndex == 0
            ? null
            : AppBar(
                leading: ModuleBackButton(onPressed: _handleBack),
                title: Text(titles[_selectedIndex]),
                actions: [ModuleHomeButton(onPressed: widget.onExitModule)],
              ),
        body: IndexedStack(index: _selectedIndex, children: pages),
      ),
    );
  }
}
