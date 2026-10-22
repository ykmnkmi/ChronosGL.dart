@TestOn("chrome")
library;

import 'package:chronosgl/chronosgl.dart';
import "package:test/test.dart";
import 'package:web/web.dart' as web;

void main() {
  test("show_extensions", () {
    final canvas = web.HTMLCanvasElement()
      ..width = 200
      ..height = 200;
    ChronosGL chronosGL = ChronosGL(canvas);
    addTearDown(() {
      final extension = chronosGL.getExtension('WEBGL_lose_context');
      if (extension != null) {
        (extension as web.WEBGL_lose_context).loseContext();
      }
    });
    List<String> exts = chronosGL.getSupportedExtensions();
    expect(exts, everyElement(isA<String>()));
    for (var e in exts) {
      print(e);
    }
    // Browsers may withhold renderer details for privacy.
    final debugInfo = chronosGL.getExtension('WEBGL_debug_renderer_info');
    if (exts.contains('WEBGL_debug_renderer_info')) {
      expect(debugInfo, isNotNull);
      final vendor = chronosGL.getParameter(glUnmaskedVendorWebgl);
      final renderer = chronosGL.getParameter(glUnmaskedRendererWebgl);
      expect(vendor, isA<String>());
      expect(renderer, isA<String>());
      print(vendor);
      print(renderer);
    } else {
      expect(debugInfo, isNull);
    }
  });

  print("PASS");
}
