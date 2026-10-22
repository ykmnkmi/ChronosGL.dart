import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// RGBA pixels in PNG order: the first row is the top of the image.
class GoldenImage {
  GoldenImage(this.width, this.height, this.rgba) {
    if (width <= 0 || height <= 0 || rgba.length != width * height * 4) {
      throw ArgumentError('Invalid RGBA image dimensions');
    }
  }

  factory GoldenImage.fromFramebuffer(int width, int height, Uint8List pixels) {
    final rgba = Uint8ClampedList(pixels.length);
    final stride = width * 4;
    for (var y = 0; y < height; y++) {
      rgba.setRange(
        y * stride,
        (y + 1) * stride,
        pixels,
        (height - 1 - y) * stride,
      );
    }
    return GoldenImage(width, height, rgba);
  }

  final int width;
  final int height;
  final Uint8ClampedList rgba;

  String encodePng() {
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.putImageData(web.ImageData(rgba.toJS, width, height.toJS), 0, 0);
    return canvas.toDataURL('image/png').split(',').last;
  }

  static Future<GoldenImage> decodePng(String png) async {
    final image = web.HTMLImageElement()..src = 'data:image/png;base64,$png';
    await image.decode().toDart;
    final width = image.naturalWidth;
    final height = image.naturalHeight;
    final canvas = web.HTMLCanvasElement()
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.drawImage(image, 0, 0);
    return GoldenImage(
      width,
      height,
      context.getImageData(0, 0, width, height).data.toDart,
    );
  }
}

/// Allows only small per-channel rounding differences; every pixel is checked.
class GoldenComparison {
  GoldenComparison(
    GoldenImage expected,
    GoldenImage actual, {
    this.channelTolerance = 2,
  }) {
    if (channelTolerance < 0 || channelTolerance > 255) {
      throw ArgumentError.value(channelTolerance, 'channelTolerance');
    }
    sameDimensions =
        expected.width == actual.width && expected.height == actual.height;
    final width = math.max(expected.width, actual.width);
    final height = math.max(expected.height, actual.height);
    final pixels = Uint8ClampedList(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final output = (y * width + x) * 4;
        final inExpected = x < expected.width && y < expected.height;
        final inActual = x < actual.width && y < actual.height;
        var different = !inExpected || !inActual;
        for (var channel = 0; channel < 4; channel++) {
          final a = inActual
              ? actual.rgba[(y * actual.width + x) * 4 + channel]
              : 0;
          final e = inExpected
              ? expected.rgba[(y * expected.width + x) * 4 + channel]
              : 0;
          final delta = (a - e).abs();
          maximumChannelDelta = math.max(maximumChannelDelta, delta);
          different = different || delta > channelTolerance;
          if (channel < 3) pixels[output + channel] = a ~/ 4;
        }
        if (different) {
          differentPixels++;
          pixels[output] = 255;
          pixels[output + 1] = 0;
          pixels[output + 2] = 255;
        }
        pixels[output + 3] = 255;
      }
    }
    diff = GoldenImage(width, height, pixels);
  }

  late final bool sameDimensions;
  final int channelTolerance;
  int differentPixels = 0;
  int maximumChannelDelta = 0;
  late final GoldenImage diff;

  bool get matches => sameDimensions && differentPixels == 0;

  Map<String, Object> get summary => {
    'sameDimensions': sameDimensions,
    'differentPixels': differentPixels,
    'maximumChannelDelta': maximumChannelDelta,
    'channelTolerance': channelTolerance,
  };
}
