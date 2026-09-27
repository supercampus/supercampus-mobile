import '../../authentication/data/auth_repository.dart';
import 'settings_api.dart';

/// A help-request topic and the office that receives it.
class SupportCategory {
  const SupportCategory({
    required this.key,
    required this.label,
    required this.handledBy,
  });

  final String key;
  final String label;

  /// Who the request goes to, e.g. "Accounts office".
  final String handledBy;
}

/// Used when `GET /support/categories` is unreachable. Mirrors the routing
/// table in the API contract; the server decides the real recipient.
const fallbackSupportCategories = <SupportCategory>[
  SupportCategory(
    key: 'fees',
    label: 'Fees & payments',
    handledBy: 'Accounts office',
  ),
  SupportCategory(key: 'hostel', label: 'Hostel & mess', handledBy: 'Hostel warden'),
  SupportCategory(
    key: 'gatepass',
    label: 'Gatepass & campus exit',
    handledBy: 'Hostel warden',
  ),
  SupportCategory(key: 'library', label: 'Library', handledBy: 'Librarian'),
  SupportCategory(
    key: 'academics',
    label: 'Attendance, marks & timetable',
    handledBy: 'Head of department',
  ),
  SupportCategory(
    key: 'canteen',
    label: 'Canteen, stationery & laundry',
    handledBy: 'Shop owners',
  ),
  SupportCategory(
    key: 'app',
    label: 'App or account problem',
    handledBy: 'Institution admin',
  ),
  SupportCategory(
    key: 'other',
    label: 'Something else',
    handledBy: 'Institution admin',
  ),
];

enum SupportTicketStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  const SupportTicketStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static SupportTicketStatus parse(Object? value) => SupportTicketStatus.values
      .firstWhere((s) => s.wireValue == value, orElse: () => open);
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.subject,
    required this.message,
    required this.status,
    this.handledBy,
    this.resolutionNote,
    this.requesterName,
    this.requesterEmail,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String category;
  final String categoryLabel;
  final String subject;
  final String message;
  final SupportTicketStatus status;
  final String? handledBy;
  final String? resolutionNote;
  final String? requesterName;
  final String? requesterEmail;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static SupportTicket fromJson(Map<dynamic, dynamic> json) => SupportTicket(
    id: cleanText(json['id']) ?? '',
    category: cleanText(json['category']) ?? 'other',
    categoryLabel:
        cleanText(json['categoryLabel']) ??
        cleanText(json['category']) ??
        'Help request',
    subject: cleanText(json['subject']) ?? 'Help request',
    message: cleanText(json['message']) ?? '',
    status: SupportTicketStatus.parse(json['status']),
    handledBy: cleanText(json['handledBy']),
    resolutionNote: cleanText(json['resolutionNote']),
    requesterName: cleanText(json['requesterName']),
    requesterEmail: cleanText(json['requesterEmail']),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '')?.toLocal(),
  );
}

abstract interface class SupportRepository {
  /// `GET /api/v1/operations/support/categories`.
  Future<List<SupportCategory>> categories();

  /// `POST /api/v1/operations/support/tickets`.
  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String message,
    Map<String, dynamic>? context,
  });

  /// `GET /api/v1/operations/support/tickets` — the caller's own requests.
  Future<List<SupportTicket>> myTickets();

  /// `GET /api/v1/operations/support/inbox` — requests routed to the caller.
  Future<List<SupportTicket>> inbox({SupportTicketStatus? status});

  /// `PUT /api/v1/operations/support/tickets/{id}`.
  Future<SupportTicket> updateTicket(
    String id, {
    required SupportTicketStatus status,
    String? note,
  });
}

class BackendSupportRepository implements SupportRepository {
  BackendSupportRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    SettingsApiClient? api,
  }) : _api =
           api ??
           SettingsApiClient(
             baseUrl: baseUrl,
             accessTokenProvider: accessTokenProvider,
           );

  final SettingsApiClient _api;

  static const _base = '/api/v1/operations/support';

  @override
  Future<List<SupportCategory>> categories() async {
    final data = await _api.send(
      'GET',
      '$_base/categories',
      fallbackError: 'Help topics could not be loaded.',
    );
    final rows = data is List ? data : const [];
    final categories = [
      for (final row in rows.whereType<Map>())
        if (cleanText(row['key']) case final key?)
          SupportCategory(
            key: key,
            label: cleanText(row['label']) ?? key,
            handledBy: cleanText(row['handledBy']) ?? 'Institution admin',
          ),
    ];
    return categories.isEmpty ? fallbackSupportCategories : categories;
  }

  @override
  Future<SupportTicket> createTicket({
    required String category,
    required String subject,
    required String message,
    Map<String, dynamic>? context,
  }) async {
    final data = await _api.send(
      'POST',
      '$_base/tickets',
      body: {
        'category': category,
        'subject': subject,
        'message': message,
        if (context != null && context.isNotEmpty) 'context': context,
      },
      fallbackError: 'Your request could not be sent. Try again.',
    );
    return SupportTicket.fromJson(data is Map ? data : const {});
  }

  @override
  Future<List<SupportTicket>> myTickets() => _list(
    '$_base/tickets',
    fallbackError: 'Your requests could not be loaded.',
  );

  @override
  Future<List<SupportTicket>> inbox({SupportTicketStatus? status}) => _list(
    '$_base/inbox',
    query: status == null ? null : {'status': status.wireValue},
    fallbackError: 'Help requests could not be loaded.',
  );

  @override
  Future<SupportTicket> updateTicket(
    String id, {
    required SupportTicketStatus status,
    String? note,
  }) async {
    final data = await _api.send(
      'PUT',
      '$_base/tickets/${Uri.encodeComponent(id)}',
      body: {
        'status': status.wireValue,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      fallbackError: 'The request could not be updated. Try again.',
    );
    return SupportTicket.fromJson(data is Map ? data : const {});
  }

  Future<List<SupportTicket>> _list(
    String path, {
    Map<String, String>? query,
    required String fallbackError,
  }) async {
    final data = await _api.send(
      'GET',
      path,
      query: query,
      fallbackError: fallbackError,
    );
    final rows = data is List ? data : const [];
    return [for (final row in rows.whereType<Map>()) SupportTicket.fromJson(row)];
  }
}
