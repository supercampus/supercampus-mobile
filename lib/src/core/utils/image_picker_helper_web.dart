import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'image_picker_helper.dart';

web.HTMLInputElement? _activeInput;

Future<PickedImage?> pickImageFile({String? dialogTitle}) async {
  _activeInput?.remove();

  final completer = Completer<PickedImage?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,image/gif'
    ..style.position = 'fixed'
    ..style.left = '-9999px'
    ..style.top = '-9999px'
    ..style.opacity = '0'
    ..style.width = '1px'
    ..style.height = '1px';

  _activeInput = input;
  web.document.body?.appendChild(input);

  void cleanup() {
    if (_activeInput == input) {
      _activeInput = null;
    }
    input.remove();
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        cleanup();
        return;
      }
      final file = files.item(0);
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        cleanup();
        return;
      }

      final reader = web.FileReader();
      reader.addEventListener(
        'loadend',
        ((web.Event _) {
          final result = reader.result;
          if (result != null && result.isA<JSArrayBuffer>()) {
            final bytes = (result as JSArrayBuffer).toDart.asUint8List();
            if (!completer.isCompleted) {
              completer.complete(PickedImage(bytes: bytes, name: file.name));
            }
          } else {
            if (!completer.isCompleted) completer.complete(null);
          }
          cleanup();
        }).toJS,
      );
      reader.addEventListener(
        'error',
        ((web.Event _) {
          if (!completer.isCompleted) completer.complete(null);
          cleanup();
        }).toJS,
      );
      reader.readAsArrayBuffer(file);
    }).toJS,
  );

  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
      cleanup();
    }).toJS,
  );

  input.click();
  return completer.future;
}
