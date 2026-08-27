import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'canteen_models.dart';
import 'canteen_repository.dart';

class BackendCanteenRepository implements CanteenRepository {
  BackendCanteenRepository({
    required String baseUrl,
    String? accessToken,
    AccessTokenProvider? accessTokenProvider,
    http.Client? client,
  }) : assert(
         accessToken != null || accessTokenProvider != null,
         'Provide an access token or token provider.',
       ),
       _baseUri = _normalizeBaseUri(baseUrl),
       _accessToken = accessToken,
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final String? _accessToken;
  final AccessTokenProvider? _accessTokenProvider;
  final http.Client _client;

  Uri _uri(String path) => _baseUri.resolve(path);

  @override
  Future<CanteenStore> loadStore() async {
    final response = await _authorizedRequest(
      (headers) => _client.get(
        _uri('/api/v1/operations/canteen/store'),
        headers: headers,
      ),
    );
    final data = _data(response);
    final user = _map(data['user']);
    final menu = _list(data['menu']).map(_menuItem).toList(growable: false);
    final shops = _list(data['shops']).map(_shop).toList(growable: false);
    final byId = {for (final item in menu) item.id: item};

    return CanteenStore(
      user: CanteenUser(
        name: _text(user['name'], fallback: 'Campus user'),
        email: _text(user['email']),
        rollNumber: _text(user['rollNumber'], fallback: 'Not assigned'),
        department: _text(user['department'], fallback: 'Not assigned'),
      ),
      walletBalance: _number(data['walletBalance']),
      shops: shops,
      assignedShopKeys: _list(data['assignedShopKeys'])
          .map((value) => _text(value))
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      menu: menu,
      orders: _list(
        data['orders'],
      ).map((value) => _order(_map(value), byId)).toList(growable: false),
      walletTransactions: _list(
        data['walletTransactions'],
      ).map((value) => _transaction(_map(value))).toList(growable: false),
      canManage: data['canManage'] == true,
      staffState: _staffState(_map(data['staffState'])),
      analytics: _analytics(_map(data['analytics'])),
    );
  }

  @override
  Future<OrderPlacementResult> placeOrder({
    required List<CartLine> lines,
  }) async {
    final body = jsonEncode({
      'lines': [
        for (final line in lines)
          {'itemId': line.item.id, 'quantity': line.quantity},
      ],
      // One key for the cart; the server derives a per-shop key from it, so
      // a retry cannot double-charge any single shop.
      'idempotencyKey': 'mobile-${DateTime.now().microsecondsSinceEpoch}',
    });
    final response = await _authorizedRequest(
      (headers) => _client.post(
        _uri('/api/v1/operations/canteen/orders'),
        headers: headers,
        body: body,
      ),
      json: true,
    );
    final data = _data(response);
    final menu = {for (final line in lines) line.item.id: line.item};
    // The cart is split into one order per shop, so this comes back as a list.
    return OrderPlacementResult(
      balance: _number(data['balance']),
      orders: _list(
        data['orders'],
      ).map((raw) => _order(_map(raw), menu)).toList(growable: false),
      transactions: _list(
        data['transactions'],
      ).map((raw) => _transaction(_map(raw))).toList(growable: false),
    );
  }

  Map<String, String> _headers(String token, {bool json = false}) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
    if (json) 'content-type': 'application/json',
  };

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) send, {
    bool json = false,
  }) async {
    var token = await _resolveAccessToken();
    var response = await send(_headers(token, json: json));
    if (response.statusCode == 401 && _accessTokenProvider != null) {
      token = await _resolveAccessToken(forceRefresh: true);
      response = await send(_headers(token, json: json));
    }
    return response;
  }

  Future<String> _resolveAccessToken({bool forceRefresh = false}) async {
    final provider = _accessTokenProvider;
    if (provider != null) return provider(forceRefresh: forceRefresh);
    return _accessToken!;
  }

  @override
  Future<WalletTopUpResult> topUpWallet(double amount) {
    throw const CanteenException(
      'Online recharge is not configured yet. Ask the accountant to credit your wallet.',
    );
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    CanteenOrderStatus status, {
    String? reason,
  }) async {
    final body = jsonEncode({
      'status': status.apiValue,
      if (reason != null) 'reason': reason,
    });
    final response = await _authorizedRequest(
      (headers) => _client.put(
        _uri('/api/v1/operations/canteen/orders/$orderId/status'),
        headers: headers,
        body: body,
      ),
      json: true,
    );
    _data(response);
  }

  @override
  Future<CanteenStaffState> updateStaffState({
    required CanteenStaffMode mode,
    bool? shopOpen,
  }) async {
    final body = jsonEncode({
      'mode': mode.name,
      if (shopOpen != null) 'shopOpen': shopOpen,
    });
    final response = await _authorizedRequest(
      (headers) => _client.put(
        _uri('/api/v1/operations/canteen/staff-state'),
        headers: headers,
        body: body,
      ),
      json: true,
    );
    return _staffState(_data(response));
  }

  @override
  Future<CanteenMenuItem> saveMenuItem(
    CanteenMenuItem item, {
    required bool create,
  }) async {
    final uri = create
        ? _uri('/api/v1/operations/canteen/menu')
        : _uri('/api/v1/operations/canteen/menu/${item.id}');
    final body = jsonEncode({
      'name': item.name,
      'description': item.description,
      'store': item.effectiveShopKey,
      'category': item.category,
      'price': item.price,
      'prepMinutes': item.prepMinutes,
      'isVegetarian': item.isVegetarian,
      'isPopular': item.isPopular,
      'isAvailable': item.isAvailable,
      'isInstant': item.isInstant,
      'imageUrl': item.imageUrl,
    });
    final response = await _authorizedRequest(
      (headers) => create
          ? _client.post(uri, headers: headers, body: body)
          : _client.put(uri, headers: headers, body: body),
      json: true,
    );
    return _menuItem(_data(response));
  }

  @override
  Future<void> deleteMenuItem(String itemId) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/v1/operations/canteen/menu/$itemId'),
        headers: headers,
      ),
    );
    if (response.statusCode != 204) _data(response);
  }

  @override
  Future<String> uploadMedia(
    Uint8List bytes, {
    required String filename,
  }) async {
    Future<http.Response> send(Map<String, String> headers) async {
      final request = http.MultipartRequest('POST', _uri('/api/media/upload'))
        ..headers.addAll(headers)
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );
      return http.Response.fromStream(await _client.send(request));
    }

    final data = _data(await _authorizedRequest(send));
    final url = _text(data['secureUrl']);
    if (url.isEmpty) {
      throw const CanteenException('The media upload did not return an image URL.');
    }
    return url;
  }

  CanteenMenuItem _menuItem(dynamic value) {
    final item = _map(value);
    final imageUrl = _text(item['imageUrl']);
    return CanteenMenuItem(
      id: _text(item['id']),
      name: _text(item['name'], fallback: 'Menu item'),
      description: _text(item['description']),
      store: MenuStoreLabel.parse(_text(item['store']).toLowerCase()),
      shopKey: _text(item['store']).toLowerCase(),
      category: _text(item['category'], fallback: 'meals'),
      price: _number(item['price']),
      isVegetarian: item['isVegetarian'] != false,
      isPopular: item['isPopular'] == true,
      isAvailable: item['isAvailable'] != false,
      isInstant: item['isInstant'] == true,
      prepMinutes: _integer(item['prepMinutes'], 10),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
    );
  }

  CanteenOrder _order(
    Map<String, dynamic> value,
    Map<String, CanteenMenuItem> menu,
  ) {
    final lines = _list(value['lines'])
        .map((raw) {
          final line = _map(raw);
          final itemId = _text(line['itemId']);
          final item =
              menu[itemId] ??
              CanteenMenuItem(
                id: itemId,
                name: _text(line['name'], fallback: 'Menu item'),
                description: '',
                store: MenuStoreLabel.parse(_text(line['store']).toLowerCase()),
                shopKey: _text(line['store']).toLowerCase(),
                category: _text(line['category'], fallback: 'meals'),
                price: _number(line['price']),
                isVegetarian: line['isVegetarian'] != false,
              );
          return CartLine(item: item, quantity: _integer(line['quantity'], 1));
        })
        .toList(growable: false);
    final status = switch (_text(value['status'])) {
      'pending' => CanteenOrderStatus.pending,
      'accepted' => CanteenOrderStatus.accepted,
      'preparing' => CanteenOrderStatus.preparing,
      'ready' => CanteenOrderStatus.ready,
      'completed' => CanteenOrderStatus.completed,
      'rejected' => CanteenOrderStatus.rejected,
      'cancelled' => CanteenOrderStatus.cancelled,
      _ => CanteenOrderStatus.pending,
    };
    return CanteenOrder(
      id: _text(value['id']),
      lines: lines,
      total: _number(value['total']),
      status: status,
      fulfilmentMode: _text(value['fulfilmentMode']) == 'dine_in'
          ? FulfilmentMode.dineIn
          : FulfilmentMode.pickup,
      createdAt: _date(value['createdAt']),
      tokenNumber: value['tokenNumber'] == null
          ? null
          : _integer(value['tokenNumber'], 0),
      // `order_number` is a serial, so it arrives as a number and `_text`
      // would drop it — which is why the queue was rendering a bare "#".
      orderNumber: _text(
        value['orderNumber'],
        fallback: value['orderNumber'] is num ? '${value['orderNumber']}' : '',
      ),
      customerName: _text(value['customerName'], fallback: 'Campus user'),
    );
  }

  CanteenStaffState _staffState(Map<String, dynamic> value) =>
      CanteenStaffState(
        mode: _text(value['mode']) == 'work'
            ? CanteenStaffMode.work
            : CanteenStaffMode.eat,
        shopOpen: value['shopOpen'] is bool ? value['shopOpen'] as bool : null,
      );

  CanteenShop _shop(dynamic value) {
    final shop = _map(value);
    return CanteenShop(
      id: _text(shop['id'], fallback: _text(shop['shopKey'])),
      shopKey: _text(shop['shopKey'], fallback: _text(shop['key'])),
      name: _text(shop['name'], fallback: 'Campus shop'),
      category: _text(shop['category'], fallback: 'shop'),
      description: _text(shop['description']),
      isActive: shop['isActive'] != false && shop['active'] != false,
    );
  }

  CanteenAnalytics _analytics(Map<String, dynamic> value) => CanteenAnalytics(
    ordersToday: _integer(value['ordersToday'], 0),
    revenueToday: _number(value['revenueToday']),
    pending: _integer(value['pending'], 0),
  );

  WalletTransaction _transaction(Map<String, dynamic> value) {
    final amount = _number(value['amount']);
    final type = amount < 0 || _text(value['transactionType']) == 'order_debit'
        ? WalletTransactionType.debit
        : WalletTransactionType.credit;
    return WalletTransaction(
      id: _text(value['id']),
      type: type,
      amount: amount.abs(),
      description: _text(value['description'], fallback: 'Wallet activity'),
      createdAt: _date(value['createdAt']),
    );
  }

  Map<String, dynamic> _data(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const CanteenException(
        'The canteen service returned an unreadable response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      throw CanteenException(
        error is Map<String, dynamic>
            ? _text(error['message'], fallback: 'The canteen request failed.')
            : 'The canteen request failed.',
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const CanteenException('The canteen response is missing data.');
    }
    return data;
  }
}

Uri _normalizeBaseUri(String value) {
  final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUrl', 'Enter a valid API base URL.');
  }
  return uri;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : const [];
String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
int _integer(dynamic value, int fallback) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;
DateTime _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal() ?? DateTime.now();
