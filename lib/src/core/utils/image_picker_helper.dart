import 'dart:typed_data';

import 'image_picker_helper_stub.dart'
    if (dart.library.js_interop) 'image_picker_helper_web.dart' as impl;

/// Result of an image picked from the user device.
class PickedImage {
  const PickedImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// Opens the platform image picker and returns the selected image bytes and file name.
///
/// On Web and iOS Safari, this ensures proper DOM attachment and avoids premature cancel
/// timeouts caused by mobile window blur/focus events.
Future<PickedImage?> pickImageFile({String? dialogTitle}) =>
    impl.pickImageFile(dialogTitle: dialogTitle);
