import 'gatepass_models.dart';

/// Where a leave pass or outpass stands *right now*, combining the approval
/// status from the server with the time window the pass was created for.
///
/// A pass is only good for its own window: [GatepassRequest.departureAt] to
/// [GatepassRequest.returnAt]. Once the return time has passed the pass is
/// [expired] — it no longer offers a QR or gate code, whatever the approval
/// status says. Terminal statuses the server has already recorded (completed,
/// rejected, cancelled) are respected as-is.
enum GatepassPassPhase {
  /// Waiting for approval, and the window has not closed yet.
  pending,

  /// Approved, but the window has not opened yet.
  upcoming,

  /// Approved and inside its window — the only phase that shows a QR.
  active,

  /// The window closed before the pass was used up (approved or pending).
  expired,

  /// The server recorded the pass as used (exit and return done).
  completed,
  rejected,
  cancelled,
}

extension GatepassPassPhaseLabel on GatepassPassPhase {
  String get label => switch (this) {
    GatepassPassPhase.pending => 'Pending approval',
    GatepassPassPhase.upcoming => 'Upcoming',
    GatepassPassPhase.active => 'Active',
    GatepassPassPhase.expired => 'Expired',
    GatepassPassPhase.completed => 'Completed',
    GatepassPassPhase.rejected => 'Rejected',
    GatepassPassPhase.cancelled => 'Cancelled',
  };

  /// Whether the pass still matters for what the student does next.
  bool get isCurrent =>
      this == GatepassPassPhase.active ||
      this == GatepassPassPhase.upcoming ||
      this == GatepassPassPhase.pending;
}

GatepassPassPhase gatepassPassPhase(GatepassRequest request, {DateTime? at}) {
  final now = at ?? DateTime.now();
  final windowClosed = !request.returnAt.isAfter(now);
  return switch (request.status) {
    ApprovalStatus.completed => GatepassPassPhase.completed,
    ApprovalStatus.rejected => GatepassPassPhase.rejected,
    ApprovalStatus.cancelled => GatepassPassPhase.cancelled,
    ApprovalStatus.pending =>
      windowClosed ? GatepassPassPhase.expired : GatepassPassPhase.pending,
    ApprovalStatus.approved =>
      windowClosed
          ? GatepassPassPhase.expired
          : request.departureAt.isAfter(now)
          ? GatepassPassPhase.upcoming
          : GatepassPassPhase.active,
  };
}
