import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a QR code out of a photo's bytes (JPEG, PNG, GIF, BMP or WebP).
///
/// Pure Dart, so it works everywhere the app runs — including the web, where
/// the camera plugin cannot read a code from an image at all. Returns null
/// when no code can be found.
///
/// Photos are rarely as clean as a camera frame: a screenshot of a pass is
/// huge, a snap of a printed code is small and uneven. So the image is tried
/// at a few sizes, with two thresholding strategies, and inverted, before
/// giving up.
String? decodeQrFromImageBytes(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Not an image this library can read (a truncated file, HEIC, …).
    return null;
  }
  if (decoded == null) return null;
  // A transparent PNG must read as dark-on-white, not dark-on-black.
  final flat = img.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: 3,
  );
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, decoded);

  final longest = flat.width > flat.height ? flat.width : flat.height;
  final sizes = <int>{
    for (final target in const [1600, 1000, 640])
      if (longest > target) target,
    if (longest <= 1600) longest,
  };
  for (final size in sizes) {
    final scaled = size == longest
        ? flat
        : img.copyResize(
            flat,
            width: flat.width >= flat.height ? size : null,
            height: flat.height > flat.width ? size : null,
            interpolation: img.Interpolation.average,
          );
    final value = _decode(scaled);
    if (value != null) return value;
  }
  return null;
}

String? _decode(img.Image image) {
  final pixels = Int32List(image.width * image.height);
  var i = 0;
  for (final p in image) {
    pixels[i++] =
        (p.r.toInt() & 0xff) << 16 |
        (p.g.toInt() & 0xff) << 8 |
        (p.b.toInt() & 0xff);
  }
  final LuminanceSource source = RGBLuminanceSource(
    image.width,
    image.height,
    pixels,
  );
  final hints = DecodeHints()..put(DecodeHintType.tryHarder);
  for (final candidate in [source, InvertedLuminanceSource(source)]) {
    for (final bitmap in [
      BinaryBitmap(HybridBinarizer(candidate)),
      BinaryBitmap(GlobalHistogramBinarizer(candidate)),
    ]) {
      try {
        final text = QRCodeReader().decode(bitmap, hints: hints).text;
        if (text.isNotEmpty) return text;
      } on ReaderException {
        // Not found with this strategy; try the next.
      } catch (_) {
        // Malformed data in one strategy should not stop the others.
      }
    }
  }
  return null;
}
