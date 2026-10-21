// This is not really a test
@TestOn("dartium")
library;

import 'dart:html' as html;
import 'dart:web_gl' as webgl;

import 'package:chronosgl/chronosgl.dart';
import "package:test/test.dart";

void main() {
  test("show_extensions", () {
    html.CanvasElement canvas = html.CanvasElement(width: 200, height: 200);
    ChronosGL chronosGL = ChronosGL(canvas);
    List<String> exts = chronosGL.getSupportedExtensions();
    for (var e in exts) {
      print(e);
    }
    webgl.DebugRendererInfo di = chronosGL.getExtension(
      'WEBGL_debug_renderer_info',
    ) as webgl.DebugRendererInfo;
    print(di);
    print(chronosGL.getParameter(glUnmaskedVendorWebgl));
    print(chronosGL.getParameter(glUnmaskedRendererWebgl));
  });

  print("PASS");
}
