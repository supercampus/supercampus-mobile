import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/utils/image_picker_helper.dart';

void main() {
  test('PickedImage model stores name and bytes correctly', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    const name = 'sample.jpg';
    final picked = PickedImage(bytes: bytes, name: name);

    expect(picked.name, name);
    expect(picked.bytes, bytes);
    expect(picked.bytes.length, 4);
  });
}
