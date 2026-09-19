import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import 'image_picker_helper.dart';

web.HTMLInputElement? _activeInput;
Completer<PickedImage?>? _activeCompleter;

Future<PickedImage?> pickImageFile({String? dialogTitle}) async {
  // Cancel and clean up any previous in-flight picker session
  if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
    _activeCompleter!.complete(null);
  }
  _activeInput?.remove();
  _activeInput = null;

  final completer = Completer<PickedImage?>();
  _activeCompleter = completer;

  // Ensure a dedicated non-interfering container exists in document body
  var container =
      web.document.querySelector('#flt-file-picker-container') as web.HTMLElement?;
  if (container == null) {
    final el = web.document.createElement('div') as web.HTMLElement
      ..id = 'flt-file-picker-container'
      ..style.position = 'fixed'
      ..style.bottom = '0'
      ..style.left = '0'
      ..style.width = '0'
      ..style.height = '0'
      ..style.opacity = '0'
      ..style.overflow = 'hidden'
      ..style.pointerEvents = 'none';
    web.document.body?.append(el);
    container = el;
  }

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.position = 'absolute'
    ..style.bottom = '0'
    ..style.left = '0'
    ..style.opacity = '0'
    ..style.width = '0'
    ..style.height = '0';

  _activeInput = input;
  container.append(input);

  void cleanup() {
    if (_activeInput == input) {
      _activeInput = null;
      _activeCompleter = null;
    }
    input.remove();
  }

  input.addEventListener(
    'change',
    ((web.Event _) async {
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

      try {
        final picked = await _processImageFile(file);
        if (!completer.isCompleted) completer.complete(picked);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      } finally {
        cleanup();
      }
    }).toJS,
  );

  // Note: On iOS Safari, opening the photo sheet causes the input to lose focus
  // or dispatch a 'cancel' event prematurely. We do NOT listen to 'cancel' with
  // immediate abort, so user selection is never interrupted.

  input.click();
  return completer.future;
}

Future<PickedImage?> _processImageFile(web.File file) async {
  // Try to transcode and optimize to JPEG via browser canvas
  // This automatically handles iPhone HEIC photos and scales down huge images.
  final convertedBytes = await _convertImageToJpeg(file);
  if (convertedBytes != null && convertedBytes.isNotEmpty) {
    final rawName = file.name.isNotEmpty ? file.name : 'upload';
    final dotIndex = rawName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? rawName.substring(0, dotIndex) : rawName;
    return PickedImage(bytes: convertedBytes, name: '$baseName.jpg');
  }

  // Fallback to reading original bytes
  final rawBytes = await _readFileBytes(file);
  if (rawBytes == null || rawBytes.isEmpty) return null;

  final fileName = file.name.isNotEmpty ? file.name : 'upload.jpg';
  return PickedImage(bytes: rawBytes, name: fileName);
}

Future<Uint8List?> _convertImageToJpeg(web.File file) async {
  try {
    final img = web.HTMLImageElement();
    final url = web.URL.createObjectURL(file);
    img.src = url;

    final loaded = Completer<bool>();
    img.addEventListener('load', ((web.Event _) => loaded.complete(true)).toJS);
    img.addEventListener(
      'error',
      ((web.Event _) => loaded.complete(false)).toJS,
    );

    final ok = await loaded.future;
    if (!ok) {
      web.URL.revokeObjectURL(url);
      return null;
    }

    int width = img.naturalWidth;
    int height = img.naturalHeight;
    if (width <= 0 || height <= 0) {
      web.URL.revokeObjectURL(url);
      return null;
    }

    const int maxDim = 1920;
    if (width > maxDim || height > maxDim) {
      if (width > height) {
        height = (height * maxDim / width).round();
        width = maxDim;
      } else {
        width = (width * maxDim / height).round();
        height = maxDim;
      }
    }

    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;

    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(img, 0, 0, width.toDouble(), height.toDouble());
    web.URL.revokeObjectURL(url);

    final dataUrl = canvas.toDataURL('image/jpeg', 0.85.toJS);
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex != -1) {
      return base64Decode(dataUrl.substring(commaIndex + 1));
    }
  } catch (_) {
    // If canvas conversion fails, fallback to raw bytes
  }
  return null;
}

Future<Uint8List?> _readFileBytes(web.File file) {
  final completer = Completer<Uint8List?>();
  final reader = web.FileReader();

  reader.addEventListener(
    'loadend',
    ((web.Event _) {
      final result = reader.result;
      if (result != null && result.isA<JSArrayBuffer>()) {
        final bytes = (result as JSArrayBuffer).toDart.asUint8List();
        completer.complete(bytes);
      } else {
        completer.complete(null);
      }
    }).toJS,
  );

  reader.addEventListener(
    'error',
    ((web.Event _) {
      completer.complete(null);
    }).toJS,
  );

  reader.readAsArrayBuffer(file);
  return completer.future;
}
