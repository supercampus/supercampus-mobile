import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/menu_item_art.dart';

void main() {
  test('Cloudinary menu photos are requested at card size', () {
    expect(
      menuItemThumbnailUrl(
        'https://res.cloudinary.com/supercampus/image/upload/v1/mec/dosa.jpg',
        pixels: 216,
      ),
      'https://res.cloudinary.com/supercampus/image/upload/'
      'c_fill,w_216,h_216,q_auto/v1/mec/dosa.jpg',
    );
  });

  test('non-Cloudinary photo URLs remain unchanged', () {
    const url = 'https://cdn.supercampus.ai/menu/dosa.jpg';
    expect(menuItemThumbnailUrl(url), url);
  });
}
