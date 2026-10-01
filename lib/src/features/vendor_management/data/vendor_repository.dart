import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'vendor_models.dart';

class VendorShop {
  const VendorShop({
    required this.id,
    required this.shopKey,
    required this.name,
    required this.category,
    required this.description,
    required this.isActive,
    required this.isOpen,
    this.mealCompliance = false,
    this.qrPayments = true,
    this.createdAt,
    this.updatedAt,
    this.sortOrder,
    this.operators = const [],
    this.parentShopKey,
  });

  final String id;
  final String shopKey;
  final String name;
  final String category;
  final String description;
  final bool isActive;
  final bool isOpen;
  final bool mealCompliance;
  final bool qrPayments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The administrator's place for this shop; null until they arrange shops.
  final int? sortOrder;

  /// Owner and captains assigned to run this shop.
  final List<ShopStaffAssignment> operators;

  /// The canteen this shop is a counter of (Meals, Snacks …). A counter has
  /// its own staff, menu and orders; its canteen holds the wallet.
  final String? parentShopKey;

  bool get isCounter =>
      parentShopKey != null && parentShopKey!.trim().isNotEmpty;

  VendorShop copyWith({
    String? id,
    String? shopKey,
    String? name,
    String? category,
    String? description,
    bool? isActive,
    bool? isOpen,
    bool? mealCompliance,
    bool? qrPayments,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
    List<ShopStaffAssignment>? operators,
  }) =>
      VendorShop(
        id: id ?? this.id,
        shopKey: shopKey ?? this.shopKey,
        name: name ?? this.name,
        category: category ?? this.category,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        isOpen: isOpen ?? this.isOpen,
        mealCompliance: mealCompliance ?? this.mealCompliance,
        qrPayments: qrPayments ?? this.qrPayments,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        sortOrder: sortOrder ?? this.sortOrder,
        operators: operators ?? this.operators,
        parentShopKey: parentShopKey,
      );

  factory VendorShop.fromJson(Map<String, dynamic> json) {
    return VendorShop(
      id: json['id']?.toString() ?? '',
      shopKey: json['shopKey']?.toString() ?? json['shop_key']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Shop',
      category: json['category']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
      isActive: json['isActive'] != false && json['is_active'] != false,
      isOpen: json['shopOpen'] != false && json['shop_open'] != false,
      mealCompliance: json['mealCompliance'] == true || json['meal_compliance'] == true,
      qrPayments: json['qrPayments'] != false && json['qr_payments'] != false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      sortOrder: json['sortOrder'] is num
          ? (json['sortOrder'] as num).toInt()
          : null,
      operators: [
        for (final item in (json['operators'] as List? ?? const []))
          if (item is Map)
            ShopStaffAssignment.fromJson(Map<String, dynamic>.from(item)),
      ],
      parentShopKey: (json['parentShopKey']?.toString().trim().isEmpty ?? true)
          ? null
          : json['parentShopKey'].toString().trim(),
    );
  }
}

/// The register in display order with each canteen's counters right under
/// it: canteens and other shops in the administrator's order, counters in
/// theirs. A counter whose canteen is missing is listed on its own.
List<VendorShop> nestCounters(List<VendorShop> shops) {
  final keys = {for (final shop in shops) shop.shopKey};
  final nested = <VendorShop>[];
  for (final shop in shops) {
    if (shop.isCounter && keys.contains(shop.parentShopKey)) continue;
    nested.add(shop);
    for (final counter in shops) {
      if (counter.parentShopKey == shop.shopKey) nested.add(counter);
    }
  }
  return nested;
}

/// One person's role at a shop.
class ShopStaffAssignment {
  const ShopStaffAssignment({
    required this.userId,
    required this.role,
    this.name,
  });

  factory ShopStaffAssignment.fromJson(Map<String, dynamic> json) =>
      ShopStaffAssignment(
        userId: json['userId']?.toString() ?? '',
        role: json['assignmentRole']?.toString() == 'owner'
            ? 'owner'
            : 'captain',
        name: json['name']?.toString(),
      );

  final String userId;

  /// `owner` or `captain`.
  final String role;
  final String? name;

  bool get isOwner => role == 'owner';

  ShopStaffAssignment withRole(String role) =>
      ShopStaffAssignment(userId: userId, role: role, name: name);

  Map<String, dynamic> toJson() => {'userId': userId, 'assignmentRole': role};
}

/// Someone an administrator may put behind a counter: an account whose
/// roles grant shop-counter work.
class ShopStaffCandidate {
  const ShopStaffCandidate({
    required this.userId,
    required this.name,
    required this.email,
    required this.suggestedRole,
  });

  final String userId;
  final String name;
  final String email;

  /// `owner` when their roles can run the menu, otherwise `captain`.
  final String suggestedRole;
}

class VendorShopDraft {
  const VendorShopDraft({
    required this.shopKey,
    required this.name,
    required this.category,
    required this.description,
    this.isActive = true,
    this.mealCompliance = false,
    this.qrPayments = true,
    this.operators,
    this.parentShopKey,
    this.sortOrder,
  });

  final String shopKey;
  final String name;
  final String category;
  final String description;
  final bool isActive;
  final bool mealCompliance;
  final bool qrPayments;

  /// The shop's full staff list. Null leaves the current staff untouched.
  final List<ShopStaffAssignment>? operators;

  /// Makes the shop a counter of this canteen. Null leaves it as it is.
  final String? parentShopKey;

  /// The shop's place in the sequence (a counter's place in its canteen).
  /// Null leaves it as it is.
  final int? sortOrder;

  Map<String, dynamic> toJson() => {
        'shopKey': shopKey.trim().toLowerCase(),
        'name': name.trim(),
        'category': category.trim(),
        'description': description.trim(),
        'isActive': isActive,
        'mealCompliance': mealCompliance,
        'qrPayments': qrPayments,
        if (operators != null)
          'operators': [for (final o in operators!) o.toJson()],
        if (parentShopKey != null) 'parentShopKey': parentShopKey,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };
}

/// Shop administration beyond the register itself: the administrator's shop
/// sequence and who works each counter. Repositories without a campus server
/// do not implement it, and the screens then leave those controls out.
abstract interface class ShopAdministration {
  /// Saves [shopKeys] as the display order every shop list follows and
  /// returns the register in that order.
  Future<List<VendorShop>> reorderVendors(List<String> shopKeys);

  /// Accounts whose roles grant counter work. Empty when the viewer cannot
  /// read the user directory.
  Future<List<ShopStaffCandidate>> listShopStaffCandidates();
}

/// Whether a role's permission keys make its holder shop staff: they run
/// orders or a menu, without the shop-configuration grant that already
/// covers every shop.
bool grantsShopCounterWork(Iterable<String> permissionKeys) {
  final keys = permissionKeys.toSet();
  if (keys.contains('vendor_management.vendors.update')) return false;
  return keys.contains('canteen.orders.manage') ||
      keys.contains('canteen.menu.create') ||
      keys.contains('canteen.menu.update') ||
      keys.contains('canteen.menu.delete');
}

/// `owner` when the permission keys can run a menu, otherwise `captain`.
String suggestedShopRole(Iterable<String> permissionKeys) {
  final keys = permissionKeys.toSet();
  return keys.contains('canteen.menu.create') ||
          keys.contains('canteen.menu.update')
      ? 'owner'
      : 'captain';
}

abstract interface class VendorRepository {
  Future<List<VendorShop>> listVendors();
  Future<VendorShop> createVendor(VendorShopDraft draft);
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft);
  Future<void> toggleVendorStatus(VendorShop shop, bool active);

  /// Sales measured over [period] in campus local time.
  Future<SalesDashboardData> getSalesDashboard({
    SalesPeriod period = SalesPeriod.today,
  });

  /// Orders and laundry charges across every shop, newest first.
  Future<SalesOrderPage> listSalesOrders({
    SalesPeriod period = SalesPeriod.all,
    String? shopKey,
    OrderStatusFilter status = OrderStatusFilter.all,
    int limit = 100,
  });
}

class BackendVendorRepository
    implements VendorRepository, ShopAdministration {
  BackendVendorRepository({
    required String baseUrl,
    String? accessToken,
    AccessTokenProvider? accessTokenProvider,
    http.Client? client,
  })  : assert(
          accessToken != null || accessTokenProvider != null,
          'Provide an access token or token provider.',
        ),
        _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _accessToken = accessToken,
        _accessTokenProvider = accessTokenProvider,
        _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final String? _accessToken;
  final AccessTokenProvider? _accessTokenProvider;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  @override
  Future<List<VendorShop>> listVendors() async {
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/canteen/shops'),
        headers: headers,
      ),
    );
    final data = _data(response);
    final shopsJson = data['shops'];
    if (shopsJson is! List) return const [];
    return shopsJson
        .whereType<Map>()
        .map((item) => VendorShop.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) async {
    final response = await _request(
      (headers) => _client.post(
        _uri('/api/v1/operations/canteen/shops'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode(draft.toJson()),
      ),
    );
    final data = _data(response);
    return VendorShop.fromJson(data);
  }

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) async {
    final response = await _request(
      (headers) => _client.put(
        _uri('/api/v1/operations/canteen/shops/$shopId'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode(draft.toJson()),
      ),
    );
    final data = _data(response);
    return VendorShop.fromJson(data);
  }

  @override
  Future<void> toggleVendorStatus(VendorShop shop, bool active) async {
    final draft = VendorShopDraft(
      shopKey: shop.shopKey,
      name: shop.name,
      category: shop.category,
      description: shop.description,
      isActive: active,
      mealCompliance: shop.mealCompliance,
      qrPayments: shop.qrPayments,
    );
    await updateVendor(shop.id, draft);
  }

  @override
  Future<SalesDashboardData> getSalesDashboard({
    SalesPeriod period = SalesPeriod.today,
  }) async {
    final uri = _uri(
      '/api/v1/operations/canteen/sales-dashboard',
    ).replace(queryParameters: {'period': period.key});
    final response = await _request(
      (headers) => _client.get(uri, headers: headers),
    );
    return SalesDashboardData.fromJson(_data(response));
  }

  @override
  Future<SalesOrderPage> listSalesOrders({
    SalesPeriod period = SalesPeriod.all,
    String? shopKey,
    OrderStatusFilter status = OrderStatusFilter.all,
    int limit = 100,
  }) async {
    final uri = _uri('/api/v1/operations/canteen/sales-dashboard/orders')
        .replace(
          queryParameters: {
            'period': period.key,
            'status': status.key,
            'limit': '$limit',
            if (shopKey != null && shopKey.isNotEmpty) 'store': shopKey,
          },
        );
    final response = await _request(
      (headers) => _client.get(uri, headers: headers),
    );
    return SalesOrderPage.fromJson(_data(response));
  }

  @override
  Future<List<VendorShop>> reorderVendors(List<String> shopKeys) async {
    final response = await _request(
      (headers) => _client.put(
        _uri('/api/v1/operations/canteen/shops/order'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({'shopKeys': shopKeys}),
      ),
    );
    final shopsJson = _data(response)['shops'];
    if (shopsJson is! List) return const [];
    return shopsJson
        .whereType<Map>()
        .map((item) => VendorShop.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<List<ShopStaffCandidate>> listShopStaffCandidates() async {
    final List<dynamic> users;
    final List<dynamic> roles;
    try {
      final responses = await Future.wait([
        _request(
          (headers) =>
              _client.get(_uri('/api/v1/authorization/users'), headers: headers),
        ),
        _request(
          (headers) =>
              _client.get(_uri('/api/v1/authorization/roles'), headers: headers),
        ),
      ]);
      users = _list(responses[0]);
      roles = _list(responses[1]);
    } catch (_) {
      // No access to the user directory: staff are then chosen from the
      // admin's user list instead.
      return const [];
    }
    final permissionsByRole = <String, List<String>>{};
    for (final role in roles.whereType<Map>()) {
      permissionsByRole[role['id']?.toString() ?? ''] = [
        for (final permission in (role['permissions'] as List? ?? const []))
          if (permission is Map && permission['key'] != null)
            permission['key'].toString(),
      ];
    }
    final candidates = <ShopStaffCandidate>[];
    for (final user in users.whereType<Map>()) {
      if (user['active'] == false) continue;
      final keys = <String>[
        for (final role in (user['roles'] as List? ?? const []))
          if (role is Map) ...?permissionsByRole[role['id']?.toString()],
      ];
      if (!grantsShopCounterWork(keys)) continue;
      candidates.add(
        ShopStaffCandidate(
          userId: user['id']?.toString() ?? '',
          name: user['name']?.toString() ?? 'Staff member',
          email: user['email']?.toString() ?? '',
          suggestedRole: suggestedShopRole(keys),
        ),
      );
    }
    candidates.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return candidates;
  }

  List<dynamic> _list(http.Response response) {
    final body = jsonDecode(response.body);
    final data = body is Map ? body['data'] : body;
    return data is List ? data : const [];
  }

  Future<http.Response> _request(
    Future<http.Response> Function(Map<String, String>) send,
  ) async {
    var token = await _token();
    var response = await send(_headers(token));
    if (response.statusCode == 401 && _accessTokenProvider != null) {
      token = await _token(forceRefresh: true);
      response = await send(_headers(token));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Vendor management request failed (${response.statusCode}).';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['message'] is String) {
          message = body['message'] as String;
        } else if (body['error'] is String) {
          message = body['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
    return response;
  }

  Future<String> _token({bool forceRefresh = false}) async {
    if (_accessTokenProvider != null) {
      final token = await _accessTokenProvider(forceRefresh: forceRefresh);
      if (token.isNotEmpty) return token;
    }
    if (_accessToken != null && _accessToken.isNotEmpty) {
      return _accessToken;
    }
    throw StateError('Missing auth token for vendor operations.');
  }

  Map<String, String> _headers(String token) => {
        'authorization': 'Bearer $token',
        'accept': 'application/json',
      };

  Map<String, dynamic> _data(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['data'] is Map<String, dynamic>) {
        return body['data'] as Map<String, dynamic>;
      }
      return body;
    } catch (_) {
      throw Exception('Invalid JSON response from vendor service.');
    }
  }
}
