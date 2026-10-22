@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:test/test.dart';

import 'support/golden_image.dart';

void main() {
  test('PNG round trip preserves orientation and colors', () async {
    final framebuffer = Uint8List.fromList([
      0, 0, 255, 255, 255, 255, 0, 255, // bottom: blue, yellow
      255, 0, 0, 255, 0, 255, 0, 255, // top: red, green
    ]);
    final image = GoldenImage.fromFramebuffer(2, 2, framebuffer);
    final decoded = await GoldenImage.decodePng(image.encodePng());
    expect(decoded.rgba, [
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      0,
      255,
      255,
      255,
      255,
      0,
      255,
    ]);
  });

  test('PNG encoding respects RGBA typed-data view boundaries', () async {
    final storage = Uint8ClampedList.fromList([
      9, 8, 7, 255, // padding
      51, 102, 153, 255,
      204, 153, 102, 255,
      6, 5, 4, 255, // padding
    ]);
    final view = Uint8ClampedList.sublistView(storage, 4, 12);
    final image = GoldenImage(2, 1, view);
    final decoded = await GoldenImage.decodePng(image.encodePng());
    expect([decoded.width, decoded.height], [2, 1]);
    expect(decoded.rgba, [51, 102, 153, 255, 204, 153, 102, 255]);
    expect(storage.sublist(0, 4), [9, 8, 7, 255]);
    expect(storage.sublist(12), [6, 5, 4, 255]);
  });

  test(
    'comparison detects color and size changes and bounds rounding tolerance',
    () {
      GoldenImage pixel(int red) =>
          GoldenImage(1, 1, Uint8ClampedList.fromList([red, 0, 0, 255]));
      expect(GoldenComparison(pixel(100), pixel(102)).matches, isTrue);
      final changed = GoldenComparison(pixel(100), pixel(103));
      expect(changed.matches, isFalse);
      expect(changed.differentPixels, 1);
      expect(changed.diff.rgba, [255, 0, 255, 255]);
      final wider = GoldenImage(
        2,
        1,
        Uint8ClampedList.fromList([100, 0, 0, 255, 0, 0, 0, 255]),
      );
      expect(GoldenComparison(pixel(100), wider).matches, isFalse);
    },
  );
}
