import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';

class LibraryBook {
  const LibraryBook({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.shelfCode,
    required this.totalCopies,
    required this.availableCopies,
    required this.isFavourite,
    this.isbn,
    this.accessionNumber,
  });

  final String id;
  final String title;
  final String author;
  final String category;
  final String shelfCode;
  final int totalCopies;
  final int availableCopies;
  final bool isFavourite;
  final String? isbn;
  final String? accessionNumber;

  bool get isAvailable => availableCopies > 0;
}

class LibraryLoan {
  const LibraryLoan({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.author,
    required this.studentName,
    required this.rollNumber,
    required this.status,
    required this.requestedAt,
    required this.renewalCount,
    required this.overdueDays,
    required this.fineAmount,
    this.dueAt,
    this.decisionNote,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String author;
  final String studentName;
  final String rollNumber;
  final String status;
  final DateTime requestedAt;
  final DateTime? dueAt;
  final int renewalCount;
  final int overdueDays;
  final double fineAmount;
  final String? decisionNote;
}

class LibraryLendingPolicy {
  const LibraryLendingPolicy({
    required this.loanDays,
    required this.finePerDay,
  });
  final int loanDays;
  final double finePerDay;
}

class LibraryBookImport {
  const LibraryBookImport({
    required this.title,
    required this.author,
    required this.totalCopies,
    this.isbn,
    this.accessionNumber,
    this.category = '',
    this.shelfCode = '',
  });
  final String title;
  final String author;
  final int totalCopies;
  final String? isbn;
  final String? accessionNumber;
  final String category;
  final String shelfCode;

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'totalCopies': totalCopies,
    if (isbn?.isNotEmpty == true) 'isbn': isbn,
    if (accessionNumber?.isNotEmpty == true) 'accessionNumber': accessionNumber,
    'category': category,
    'shelfCode': shelfCode,
  };
}

class LibraryLendingRepository {
  LibraryLendingRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  Future<List<LibraryBook>> catalog() async {
    final data = _data(await _get('/api/v1/operations/library/catalog'));
    return _maps(data['books']).map(_book).toList(growable: false);
  }

  Future<List<LibraryLoan>> loans() async {
    final data = _data(await _get('/api/v1/operations/library/loans'));
    return _maps(data['loans']).map(_loan).toList(growable: false);
  }

  Future<LibraryLendingPolicy> policy() async {
    final data = _data(
      await _get('/api/v1/operations/library/lending-settings'),
    );
    return LibraryLendingPolicy(
      loanDays: _integer(data['loanDays'], 30),
      finePerDay: _number(data['finePerDay']),
    );
  }

  Future<void> requestBorrow(String bookId) async {
    _data(await _post('/api/v1/operations/library/loans', {'bookId': bookId}));
  }

  Future<void> renew(String loanId) async {
    _data(
      await _post('/api/v1/operations/library/loans/$loanId/renew', const {}),
    );
  }

  Future<void> setFavourite(String bookId, bool favourite) async {
    final path = '/api/v1/operations/library/favourites/$bookId';
    _data(favourite ? await _post(path, const {}) : await _delete(path));
  }

  Future<void> decide(String loanId, String decision, {String? note}) async {
    _data(
      await _post('/api/v1/operations/library/loans/$loanId/decision', {
        'decision': decision,
        if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
      }),
    );
  }

  Future<void> markReturned(String loanId) async {
    _data(
      await _post('/api/v1/operations/library/loans/$loanId/return', const {}),
    );
  }

  Future<void> updatePolicy({
    required int loanDays,
    required double finePerDay,
  }) async {
    _data(
      await _put('/api/v1/operations/library/lending-settings', {
        'loanDays': loanDays,
        'finePerDay': finePerDay,
      }),
    );
  }

  Future<int> importBooks(List<LibraryBookImport> books) async {
    final data = _data(
      await _post('/api/v1/operations/library/books/import', {
        'books': books.map((book) => book.toJson()).toList(growable: false),
      }),
    );
    return _integer(data['imported'], 0);
  }

  Future<http.Response> _get(String path) =>
      _request((headers) => _client.get(_uri(path), headers: headers));

  Future<http.Response> _delete(String path) =>
      _request((headers) => _client.delete(_uri(path), headers: headers));

  Future<http.Response> _post(String path, Map<String, dynamic> body) =>
      _request(
        (headers) =>
            _client.post(_uri(path), headers: headers, body: jsonEncode(body)),
        json: true,
      );

  Future<http.Response> _put(String path, Map<String, dynamic> body) =>
      _request(
        (headers) =>
            _client.put(_uri(path), headers: headers, body: jsonEncode(body)),
        json: true,
      );

  Future<http.Response> _request(
    Future<http.Response> Function(Map<String, String>) send, {
    bool json = false,
  }) async {
    var token = await _accessTokenProvider(forceRefresh: false);
    var response = await send(_headers(token, json: json));
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await send(_headers(token, json: json));
    }
    return response;
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
    if (json) 'content-type': 'application/json',
  };

  Map<String, dynamic> _data(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      throw StateError(
        error is String
            ? error
            : error is Map && error['message'] is String
            ? error['message'] as String
            : 'Library request failed (${response.statusCode}).',
      );
    }
    return decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : <String, dynamic>{};
  }

  Iterable<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from)
      : const [];

  LibraryBook _book(Map<String, dynamic> value) => LibraryBook(
    id: '${value['id']}',
    title: '${value['title'] ?? 'Untitled'}',
    author: '${value['author'] ?? ''}',
    category: '${value['category'] ?? ''}',
    shelfCode: '${value['shelfCode'] ?? ''}',
    totalCopies: _integer(value['totalCopies'], 1),
    availableCopies: _integer(value['availableCopies'], 0),
    isFavourite: value['isFavourite'] == true,
    isbn: value['isbn']?.toString(),
    accessionNumber: value['accessionNumber']?.toString(),
  );

  LibraryLoan _loan(Map<String, dynamic> value) => LibraryLoan(
    id: '${value['id']}',
    bookId: '${value['bookId']}',
    bookTitle: '${value['bookTitle'] ?? 'Book'}',
    author: '${value['author'] ?? ''}',
    studentName: '${value['studentName'] ?? 'Student'}',
    rollNumber: '${value['rollNumber'] ?? ''}',
    status: '${value['status'] ?? 'requested'}',
    requestedAt:
        DateTime.tryParse('${value['requestedAt']}')?.toLocal() ??
        DateTime.now(),
    dueAt: DateTime.tryParse('${value['dueAt'] ?? ''}')?.toLocal(),
    renewalCount: _integer(value['renewalCount'], 0),
    overdueDays: _integer(value['overdueDays'], 0),
    fineAmount: _number(value['fineAmount']),
    decisionNote: value['decisionNote']?.toString(),
  );

  int _integer(dynamic value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
