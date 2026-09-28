import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supercampus_mobile/src/features/scanner/data/qr_image_decoder.dart';
import 'package:zxing2/qrcode.dart';

/// Draws [text] as a QR code on a canvas, the way a screenshot or a photo of
/// a pass would carry it: a quiet zone, then extra page around it.
img.Image _qrPicture(
  String text, {
  int module = 8,
  int margin = 120,
  img.Color? ink,
}) {
  final code = Encoder.encode(text, ErrorCorrectionLevel.m);
  final matrix = code.matrix!;
  final side = matrix.width * module + margin * 2;
  final canvas = img.Image(width: side, height: side + 200);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  final colour = ink ?? img.ColorRgb8(0, 0, 0);
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) == 1) {
        img.fillRect(
          canvas,
          x1: margin + x * module,
          y1: 100 + margin + y * module,
          x2: margin + (x + 1) * module - 1,
          y2: 100 + margin + (y + 1) * module - 1,
          color: colour,
        );
      }
    }
  }
  return canvas;
}

void main() {
  const orderId = '29423be5-bebe-4aac-b794-916857ce2a22';

  test('reads an order QR from a PNG screenshot', () {
    final png = Uint8List.fromList(img.encodePng(_qrPicture(orderId)));
    expect(decodeQrFromImageBytes(png), orderId);
  });

  test('reads a laundry QR from a JPEG photo', () {
    const laundry = 'supercampus://laundry/4f1b2c3d5e6f';
    final jpg = Uint8List.fromList(
      img.encodeJpg(_qrPicture(laundry, module: 14), quality: 80),
    );
    expect(decodeQrFromImageBytes(jpg), laundry);
  });

  test('reads a coloured QR on white, as the app draws its passes', () {
    final png = Uint8List.fromList(
      img.encodePng(_qrPicture(orderId, ink: img.ColorRgb8(0x7B, 0x42, 0xF6))),
    );
    expect(decodeQrFromImageBytes(png), orderId);
  });

  test('a photo without a code, or not an image, gives null', () {
    final blank = img.Image(width: 400, height: 400);
    img.fill(blank, color: img.ColorRgb8(240, 240, 240));
    expect(
      decodeQrFromImageBytes(Uint8List.fromList(img.encodePng(blank))),
      isNull,
    );
    expect(decodeQrFromImageBytes(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
