import '../../../core/access/effective_permissions.dart';

/// Grants for the Admin Desk system pages. Each page is shown only to people
/// whose requests will succeed; the backend enforces the same keys.
bool canViewAuditLogs(EffectivePermissions permissions) =>
    permissions.can('administration', 'audit_logs', 'read');

bool canViewSecurityLogs(EffectivePermissions permissions) =>
    permissions.can('administration', 'security_logs', 'read');

bool canRevokeSessions(EffectivePermissions permissions) =>
    permissions.can('administration', 'security_logs', 'revoke');

bool canViewAppVersions(EffectivePermissions permissions) =>
    permissions.can('administration', 'app_versions', 'read') ||
    canManageAppVersions(permissions);

bool canManageAppVersions(EffectivePermissions permissions) =>
    permissions.can('administration', 'app_versions', 'update');

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double? _number(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};

int _int(Object? value) => switch (value) {
  num() => value.toInt(),
  String() => int.tryParse(value) ?? 0,
  _ => 0,
};

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

// ---------------------------------------------------------------------------
// Finance audit
// ---------------------------------------------------------------------------

/// Kinds of finance audit entries, keyed as the backend sends them.
enum AuditKind {
  topUp('top_up', 'Wallet top-up'),
  onlineTopUp('online_top_up', 'Online top-up'),
  deduction('deduction', 'Deduction'),
  refund('refund', 'Refund'),
  orderDebit('order_debit', 'Order payment'),
  laundryPayment('laundry_payment', 'Laundry payment'),
  paymentRequest('payment_request', 'Payment request paid'),
  paymentRequestIssued('payment_request_issued', 'Payment request issued'),
  onlinePayment('online_payment', 'Razorpay payment'),
  feePayment('fee_payment', 'Fee payment link'),
  other('other', 'Other');

  const AuditKind(this.key, this.label);

  final String key;
  final String label;

  static AuditKind parse(Object? value) => AuditKind.values.firstWhere(
    (kind) => kind.key == value?.toString(),
    orElse: () => AuditKind.other,
  );
}

enum AuditDirection { credit, debit, payment }

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.source,
    required this.kind,
    required this.direction,
    required this.amount,
    required this.createdAt,
    this.userId,
    this.targetName,
    this.targetNumber,
    this.targetEmail,
    this.actorUserId,
    this.actorName,
    this.shopKey,
    this.shopName,
    this.description,
    this.reference,
    this.status,
    this.balanceBefore,
    this.balanceAfter,
    this.details = const {},
  });

  final String id;
  final String source;
  final AuditKind kind;
  final AuditDirection direction;

  /// Signed for wallet entries (credit positive, debit negative); the gross
  /// amount for payments.
  final double amount;
  final DateTime? createdAt;
  final String? userId;
  final String? targetName;
  final String? targetNumber;
  final String? targetEmail;
  final String? actorUserId;
  final String? actorName;
  final String? shopKey;
  final String? shopName;
  final String? description;
  final String? reference;
  final String? status;
  final double? balanceBefore;
  final double? balanceAfter;
  final Map<String, dynamic> details;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id']?.toString() ?? '',
    source: json['source']?.toString() ?? '',
    kind: AuditKind.parse(json['kind']),
    direction: switch (json['direction']) {
      'credit' => AuditDirection.credit,
      'debit' => AuditDirection.debit,
      _ => AuditDirection.payment,
    },
    amount: _number(json['amount']) ?? 0,
    createdAt: _date(json['createdAt']),
    userId: _text(json['userId']),
    targetName: _text(json['targetName']),
    targetNumber: _text(json['targetNumber']),
    targetEmail: _text(json['targetEmail']),
    actorUserId: _text(json['actorUserId']),
    actorName: _text(json['actorName']),
    shopKey: _text(json['shopKey']),
    shopName: _text(json['shopName']),
    description: _text(json['description']),
    reference: _text(json['reference']),
    status: _text(json['status']),
    balanceBefore: _number(json['balanceBefore']),
    balanceAfter: _number(json['balanceAfter']),
    details: _map(json['details']),
  );

  /// Who performed it, or "System" for automatic and self-service entries.
  String get actorLabel =>
      actorName ?? (actorUserId == null ? 'System' : actorUserId!);
}

class AuditFilter {
  const AuditFilter({
    this.kinds = const {},
    this.direction,
    this.from,
    this.to,
    this.search = '',
    this.actor = '',
  });

  final Set<AuditKind> kinds;
  final AuditDirection? direction;
  final DateTime? from;
  final DateTime? to;
  final String search;
  final String actor;

  bool get isEmpty =>
      kinds.isEmpty &&
      direction == null &&
      from == null &&
      to == null &&
      search.trim().isEmpty &&
      actor.trim().isEmpty;

  AuditFilter copyWith({
    Set<AuditKind>? kinds,
    AuditDirection? direction,
    bool clearDirection = false,
    DateTime? from,
    bool clearFrom = false,
    DateTime? to,
    bool clearTo = false,
    String? search,
    String? actor,
  }) => AuditFilter(
    kinds: kinds ?? this.kinds,
    direction: clearDirection ? null : direction ?? this.direction,
    from: clearFrom ? null : from ?? this.from,
    to: clearTo ? null : to ?? this.to,
    search: search ?? this.search,
    actor: actor ?? this.actor,
  );

  Map<String, String> toQuery({required int limit, required int offset}) => {
    if (kinds.isNotEmpty) 'kind': kinds.map((kind) => kind.key).join(','),
    if (direction != null) 'direction': direction!.name,
    if (from != null) 'from': _day(from!),
    if (to != null) 'to': _day(to!),
    if (search.trim().isNotEmpty) 'q': search.trim(),
    if (actor.trim().isNotEmpty) 'actor': actor.trim(),
    'limit': '$limit',
    'offset': '$offset',
  };
}

String _day(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

class AuditPage {
  const AuditPage({
    required this.entries,
    required this.total,
    this.credits = 0,
    this.debits = 0,
    this.payments = 0,
    this.byKind = const {},
  });

  final List<AuditEntry> entries;
  final int total;
  final double credits;
  final double debits;
  final double payments;
  final Map<AuditKind, int> byKind;

  factory AuditPage.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);
    final byKind = <AuditKind, int>{};
    _map(summary['byKind']).forEach((key, value) {
      byKind[AuditKind.parse(key)] = _int(value);
    });
    return AuditPage(
      entries: (json['entries'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => AuditEntry.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
      total: _int(json['total']),
      credits: _number(summary['credits']) ?? 0,
      debits: _number(summary['debits']) ?? 0,
      payments: _number(summary['payments']) ?? 0,
      byKind: byKind,
    );
  }
}

// ---------------------------------------------------------------------------
// Security logs
// ---------------------------------------------------------------------------

enum SessionStatus { active, revoked, expired }

class LoginSession {
  const LoginSession({
    required this.id,
    required this.status,
    this.userId,
    this.name,
    this.email,
    this.roles = const [],
    this.deviceId,
    this.deviceName,
    this.platform,
    this.appVersion,
    this.ipAddress,
    this.userAgent,
    this.endReason,
    this.endedByName,
    this.signedInAt,
    this.lastSeenAt,
    this.expiresAt,
    this.endedAt,
    this.current = false,
  });

  final String id;
  final SessionStatus status;
  final String? userId;
  final String? name;
  final String? email;
  final List<String> roles;
  final String? deviceId;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final String? ipAddress;
  final String? userAgent;

  /// `signed_out`, `revoked_by_admin`, `signed_in_elsewhere`,
  /// `signed_in_again`, `expired` or `ended`.
  final String? endReason;
  final String? endedByName;
  final DateTime? signedInAt;
  final DateTime? lastSeenAt;
  final DateTime? expiresAt;
  final DateTime? endedAt;

  /// The administrator's own session.
  final bool current;

  factory LoginSession.fromJson(Map<String, dynamic> json) => LoginSession(
    id: json['id']?.toString() ?? '',
    status: switch (json['status']) {
      'revoked' => SessionStatus.revoked,
      'expired' => SessionStatus.expired,
      _ => SessionStatus.active,
    },
    userId: _text(json['userId']),
    name: _text(json['name']),
    email: _text(json['email']),
    roles: (json['roles'] as List? ?? const [])
        .map((role) => role.toString())
        .toList(),
    deviceId: _text(json['deviceId']),
    deviceName: _text(json['deviceName']),
    platform: _text(json['platform']),
    appVersion: _text(json['appVersion']),
    ipAddress: _text(json['ipAddress']),
    userAgent: _text(json['userAgent']),
    endReason: _text(json['endReason']),
    endedByName: _text(json['endedByName']),
    signedInAt: _date(json['signedInAt']),
    lastSeenAt: _date(json['lastSeenAt']),
    expiresAt: _date(json['expiresAt']),
    endedAt: _date(json['endedAt']),
    current: json['current'] == true,
  );

  LoginSession revoked() => LoginSession(
    id: id,
    status: SessionStatus.revoked,
    userId: userId,
    name: name,
    email: email,
    roles: roles,
    deviceId: deviceId,
    deviceName: deviceName,
    platform: platform,
    appVersion: appVersion,
    ipAddress: ipAddress,
    userAgent: userAgent,
    endReason: 'revoked_by_admin',
    signedInAt: signedInAt,
    lastSeenAt: lastSeenAt,
    expiresAt: expiresAt,
    endedAt: DateTime.now(),
    current: current,
  );

  String get displayName => name ?? email ?? 'Campus member';
}

String sessionEndLabel(String? reason) => switch (reason) {
  'signed_out' => 'Signed out',
  'revoked_by_admin' => 'Revoked by an administrator',
  'signed_in_elsewhere' => 'Signed in on another device',
  'signed_in_again' => 'Signed in again on this device',
  'expired' => 'Expired',
  null => '',
  _ => 'Ended',
};

enum LoginOutcome { success, failure, blocked, signedOut, revoked }

class LoginEventRecord {
  const LoginEventRecord({
    required this.id,
    required this.outcome,
    this.reason,
    this.name,
    this.email,
    this.sessionId,
    this.deviceId,
    this.deviceName,
    this.platform,
    this.appVersion,
    this.ipAddress,
    this.userAgent,
    this.actorName,
    this.createdAt,
  });

  final String id;
  final LoginOutcome outcome;
  final String? reason;
  final String? name;
  final String? email;
  final String? sessionId;
  final String? deviceId;
  final String? deviceName;
  final String? platform;
  final String? appVersion;
  final String? ipAddress;
  final String? userAgent;
  final String? actorName;
  final DateTime? createdAt;

  factory LoginEventRecord.fromJson(Map<String, dynamic> json) =>
      LoginEventRecord(
        id: json['id']?.toString() ?? '',
        outcome: switch (json['outcome']) {
          'failure' => LoginOutcome.failure,
          'blocked' => LoginOutcome.blocked,
          'signed_out' => LoginOutcome.signedOut,
          'revoked' => LoginOutcome.revoked,
          _ => LoginOutcome.success,
        },
        reason: _text(json['reason']),
        name: _text(json['name']),
        email: _text(json['email']),
        sessionId: _text(json['sessionId']),
        deviceId: _text(json['deviceId']),
        deviceName: _text(json['deviceName']),
        platform: _text(json['platform']),
        appVersion: _text(json['appVersion']),
        ipAddress: _text(json['ipAddress']),
        userAgent: _text(json['userAgent']),
        actorName: _text(json['actorName']),
        createdAt: _date(json['createdAt']),
      );

  String get title => switch (outcome) {
    LoginOutcome.success => 'Signed in',
    LoginOutcome.failure => 'Sign-in failed',
    LoginOutcome.blocked => switch (reason) {
      'active_on_another_device' => 'Refused: active on another device',
      'maintenance' => 'Refused: maintenance',
      _ => 'Sign-in refused',
    },
    LoginOutcome.signedOut => 'Signed out',
    LoginOutcome.revoked => 'Session revoked',
  };
}

class SessionsPage {
  const SessionsPage({
    required this.sessions,
    required this.total,
    this.active = 0,
    this.revoked = 0,
    this.expired = 0,
  });

  final List<LoginSession> sessions;
  final int total;
  final int active;
  final int revoked;
  final int expired;

  factory SessionsPage.fromJson(Map<String, dynamic> json) {
    final counts = _map(json['counts']);
    return SessionsPage(
      sessions: (json['sessions'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => LoginSession.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      total: _int(json['total']),
      active: _int(counts['active']),
      revoked: _int(counts['revoked']),
      expired: _int(counts['expired']),
    );
  }
}

class LoginEventsPage {
  const LoginEventsPage({
    required this.events,
    required this.total,
    this.successes = 0,
    this.failures = 0,
    this.blocked = 0,
    this.signedOut = 0,
  });

  final List<LoginEventRecord> events;
  final int total;
  final int successes;
  final int failures;
  final int blocked;
  final int signedOut;

  factory LoginEventsPage.fromJson(Map<String, dynamic> json) {
    final counts = _map(json['counts']);
    return LoginEventsPage(
      events: (json['events'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                LoginEventRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      total: _int(json['total']),
      successes: _int(counts['success']),
      failures: _int(counts['failure']),
      blocked: _int(counts['blocked']),
      signedOut: _int(counts['signedOut']),
    );
  }
}

class SecurityLogQuery {
  const SecurityLogQuery({
    this.status,
    this.outcome,
    this.search = '',
    this.from,
    this.to,
  });

  final SessionStatus? status;
  final LoginOutcome? outcome;
  final String search;
  final DateTime? from;
  final DateTime? to;

  Map<String, String> toQuery({required int limit, required int offset}) => {
    if (status != null) 'status': status!.name,
    if (outcome != null)
      'outcome': switch (outcome!) {
        LoginOutcome.signedOut => 'signed_out',
        final other => other.name,
      },
    if (search.trim().isNotEmpty) 'q': search.trim(),
    if (from != null) 'from': _day(from!),
    if (to != null) 'to': _day(to!),
    'limit': '$limit',
    'offset': '$offset',
  };
}

// ---------------------------------------------------------------------------
// App versions
// ---------------------------------------------------------------------------

class AppVersionPolicy {
  const AppVersionPolicy({
    required this.platform,
    required this.latestVersion,
    required this.minimumVersion,
    this.storeUrl = '',
    this.forceUpdate = false,
    this.updatedBy,
    this.updatedAt,
  });

  /// `android` or `ios`.
  final String platform;
  final String latestVersion;
  final String minimumVersion;
  final String storeUrl;
  final bool forceUpdate;
  final String? updatedBy;
  final DateTime? updatedAt;

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) =>
      AppVersionPolicy(
        platform: json['platform']?.toString() ?? '',
        latestVersion: json['latestVersion']?.toString() ?? '0.0.0',
        minimumVersion: json['minimumVersion']?.toString() ?? '0.0.0',
        storeUrl: json['storeUrl']?.toString() ?? '',
        forceUpdate: json['forceUpdate'] == true,
        updatedBy: _text(json['updatedBy']),
        updatedAt: _date(json['updatedAt']),
      );

  Map<String, dynamic> toUpdateJson() => {
    'latestVersion': latestVersion.trim(),
    'minimumVersion': minimumVersion.trim(),
    'storeUrl': storeUrl.trim(),
    'forceUpdate': forceUpdate,
  };

  String get platformLabel => platform == 'ios' ? 'iOS' : 'Android';
}

/// Numeric parts of `1.2.3`, `1.2.3+45` or `v1.2`; null when unreadable.
List<int>? parseAppVersion(String value) {
  var core = value.trim().split(RegExp('[+-]')).first;
  if (core.startsWith('v') || core.startsWith('V')) core = core.substring(1);
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final part in core.split('.')) {
    final number = int.tryParse(part);
    if (number == null || number < 0) return null;
    parts.add(number);
  }
  return parts.isEmpty || parts.length > 4 ? null : parts;
}

/// Negative when [a] is older than [b]; null when either is unreadable.
int? compareAppVersions(String a, String b) {
  final left = parseAppVersion(a);
  final right = parseAppVersion(b);
  if (left == null || right == null) return null;
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

enum AppUpdateRequirement { none, recommended, required }

/// Below minimum, or below latest with force update on → required (blocking).
/// Below latest otherwise → recommended (dismissible).
AppUpdateRequirement evaluateAppUpdate(
  String currentVersion,
  AppVersionPolicy policy,
) {
  bool below(String target) =>
      (compareAppVersions(currentVersion, target) ?? 0) < 0;
  if (below(policy.minimumVersion) ||
      (policy.forceUpdate && below(policy.latestVersion))) {
    return AppUpdateRequirement.required;
  }
  if (below(policy.latestVersion)) return AppUpdateRequirement.recommended;
  return AppUpdateRequirement.none;
}
