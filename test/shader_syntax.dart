@TestOn("chrome")
library;

import 'package:chronosgl/chronosgl.dart';
import "package:test/test.dart";
import 'package:web/web.dart' as web;

void main() {
  test("shader_syntax", () {
    final canvas = web.HTMLCanvasElement()
      ..width = 200
      ..height = 200;
    ChronosGL cgl = ChronosGL.fromCanvas(canvas);
    addTearDown(() {
      final extension = cgl.getExtension('WEBGL_lose_context');
      if (extension != null) {
        (extension as web.WEBGL_lose_context).loseContext();
      }
    });
    for (final (vertex, fragment) in [
      (texturedVertexShader, texturedFragmentShader),
      (lightVertexShaderGourad, lightFragmentShaderGourad),
      (lightVertexShaderBlinnPhong, lightFragmentShaderBlinnPhong),
      (copyVertexShader, copyFragmentShader),
      (ssaoVertexShader, ssaoFragmentShader),
      (sobelVertexShader, sobelFragmentShader),
    ]) {
      final program = RenderProgram.create(
        name: 'prog',
        context: cgl,
        vertexShader: vertex,
        fragmentShader: fragment,
      );
      addTearDown(program.dispose);
      expect(program.isDisposed, isFalse);
    }
  });

  print("PASS");
}
