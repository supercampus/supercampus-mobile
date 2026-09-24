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
    );
  }
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
  });

  final String shopKey;
  final String name;
  final String category;
  final String description;
  final bool isActive;
  final bool mealCompliance;
  final bool qrPayments;

  Map<String, dynamic> toJson() => {
        'shopKey': shopKey.trim().toLowerCase(),
        'name': name.trim(),
        'category': category.trim(),
        'description': description.trim(),
        'isActive': isActive,
        'mealCompliance': mealCompliance,
        'qrPayments': qrPayments,
      };
}

abstract interface class VendorRepository {
  Future<List<VendorShop>> listVendors();
  Future<VendorShop> createVendor(VendorShopDraft draft);
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft);
  Future<void> toggleVendorStatus(VendorShop shop, bool active);
  Future<SalesDashboardData> getSalesDashboard();
}

class BackendVendorRepository implements VendorRepository {
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
  Future<SalesDashboardData> getSalesDashboard() async {
    final response = await _request(
      (headers) => _client.get(
        _uri('/api/v1/operations/canteen/sales-dashboard'),
        headers: headers,
      ),
    );
    final data = _data(response);
    return SalesDashboardData.fromJson(data);
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
