import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/canteen/data/backend_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';

void main() {
  test('saveMenuItem sends valid fields conforming to backend MenuItemRequest without unknown cost field', () async {
    Map<String, dynamic>? capturedBody;
    String? capturedMethod;

    final client = MockClient((request) async {
      capturedMethod = request.method;
      capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

      return http.Response(
        jsonEncode({
          'data': {
            'id': 'item-123',
            'name': capturedBody!['name'],
            'description': capturedBody!['description'],
            'store': capturedBody!['store'],
            'category': capturedBody!['category'],
            'price': capturedBody!['price'],
            'actualPrice': capturedBody!['actualPrice'],
            'prepMinutes': capturedBody!['prepMinutes'],
            'isVegetarian': capturedBody!['isVegetarian'],
            'isPopular': capturedBody!['isPopular'],
            'isAvailable': capturedBody!['isAvailable'],
            'isInstant': capturedBody!['isInstant'],
            'imageUrl': capturedBody!['imageUrl'],
          }
        }),
        201,
      );
    });

    final repo = BackendCanteenRepository(
      baseUrl: 'https://api.supercampus.ai',
      client: client,
      accessToken: 'test-token',
    );

    const itemToSave = CanteenMenuItem(
      id: '',
      name: 'Paneer Butter Masala',
      description: 'Rich gravy',
      category: 'Curries',
      price: 180.0,
      cost: 110.0,
      isVegetarian: true,
      shopKey: 'classic',
    );

    final saved = await repo.saveMenuItem(itemToSave, create: true);

    expect(capturedMethod, 'POST');
    expect(capturedBody, isNotNull);
    // Crucial: Serde backend rejects unknown fields with deny_unknown_fields
    expect(capturedBody!.containsKey('cost'), isFalse);
    expect(capturedBody!['price'], 180.0);
    expect(capturedBody!['actualPrice'], 110.0); // Cost mapped to actualPrice
    expect(capturedBody!['name'], 'Paneer Butter Masala');
    expect(capturedBody!['store'], 'classic');
    expect(capturedBody!['category'], 'Curries');

    // Model correctly populated from response
    expect(saved.id, 'item-123');
    expect(saved.price, 180.0);
    expect(saved.cost, 110.0);
    expect(saved.actualPrice, 110.0);
    expect(saved.profit, 70.0);
  });
}
