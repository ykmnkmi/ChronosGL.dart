@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

ChronosGL _context() {
  final canvas = web.HTMLCanvasElement()
    ..width = 2
    ..height = 2;
  final cgl = ChronosGL(
    canvas,
    antialiasing: false,
    preserveDrawingBuffer: true,
  );
  addTearDown(() {
    (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
        ?.loseContext();
  });
  cgl.viewport(0, 0, 2, 2);
  cgl.disable(glDepthTest);
  cgl.disable(glDither);
  return cgl;
}

MeshData _triangle(RenderProgram program) =>
    program.makeMeshData('fullscreen triangle', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]));

void _expectPixels(ChronosGL cgl, List<int> rgba) {
  final pixels = Uint8List(2 * 2 * 4);
  cgl.readPixels(0, 0, 2, 2, glRgba, glUnsignedByte, pixels);
  expect(pixels, [for (var i = 0; i < 4; i++) ...rgba]);
  expect(cgl.getError(), glNoError);
}

void main() {
  for (final stage in ['vertex', 'fragment', 'both']) {
    test('Ignores uniforms optimized out of the $stage shader(s)', () {
      final cgl = _context();
      final vertex = ShaderObject('unused-$stage-v')
        ..addAttributeVars([aPosition])
        ..addUniformVars([uScale, if (stage != 'fragment') uTime])
        ..setBodyWithMain(['gl_Position = vec4($aPosition * $uScale, 1.0);']);
      final fragment = ShaderObject('unused-$stage-f')
        // uScale is shared by both declarations but used only in the vertex
        // shader. Its location must remain active for the linked program.
        ..addUniformVars([uScale, uColor, if (stage != 'vertex') uTime])
        ..setBodyWithMain(['$oFragColor = vec4($uColor, 1.0);']);

      final program = RenderProgram('unused-$stage', cgl, vertex, fragment);
      expect(
        program.uninitializedInputs(),
        unorderedEquals([aPosition, uScale, uColor]),
      );
      final mesh = _triangle(program);
      final uniforms = UniformGroup('active')..setUniform(uScale, 1.0);

      // Missing active uniforms must still be reported after a draw.
      program.draw(mesh, [uniforms]);
      expect(program.uninitializedInputs(), [uColor]);

      uniforms.setUniform(uColor, vm.Vector3(1, 0, 0));
      program.draw(mesh, [uniforms]);
      expect(program.uninitializedInputs(), isEmpty);
      _expectPixels(cgl, [255, 0, 0, 255]);

      // Inactive values must be skipped before conversion or GPU upload.
      uniforms.setUniform(uTime, Object());
      uniforms.forceUniform(uColor, vm.Vector3(0, 1, 0));
      program.draw(mesh, [uniforms]);
      expect(program.uninitializedInputs(), isEmpty);
      _expectPixels(cgl, [0, 255, 0, 255]);
    });
  }

  test('Draws when all uniforms, including a sampler, are optimized out', () {
    final cgl = _context();
    final vertex = ShaderObject('all-unused-v')
      ..addAttributeVars([aPosition])
      ..addUniformVars([uTime])
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('all-unused-f')
      ..addUniformVars([uTexture])
      ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
    final program = RenderProgram('all-unused', cgl, vertex, fragment);
    expect(program.uninitializedInputs(), [aPosition]);
    final mesh = _triangle(program);

    program.draw(mesh, []);
    expect(program.uninitializedInputs(), isEmpty);
    _expectPixels(cgl, [255, 255, 255, 255]);

    final unused = UniformGroup('unused')
      ..setUniform(uTime, Object())
      ..setUniform(uTexture, Object());
    program.draw(mesh, [unused]);
    expect(program.uninitializedInputs(), isEmpty);
    _expectPixels(cgl, [255, 255, 255, 255]);
  });
}
