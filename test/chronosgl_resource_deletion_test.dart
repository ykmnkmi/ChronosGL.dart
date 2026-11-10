@TestOn('chrome')
library;

import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

const _vertexSource = '''#version 300 es
void main() { gl_Position = vec4(0.0, 0.0, 0.0, 1.0); }
''';
const _fragmentSource = '''#version 300 es
precision mediump float;
out vec4 color;
void main() { color = vec4(1.0); }
''';

void main() {
  late ChronosGL cgl;
  late web.WebGL2RenderingContext gl;

  setUp(() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = ChronosGL(canvas, antialiasing: false);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
  });

  // Query the real context so a missing/no-op wrapper cannot pass these tests.
  void expectDeleted(void Function() delete, bool Function() isResource) {
    expect(isResource(), isTrue);
    expect(cgl.getError(), glNoError);
    delete();
    expect(isResource(), isFalse);
    expect(cgl.getError(), glNoError);
    delete();
    expect(isResource(), isFalse);
    expect(cgl.getError(), glNoError);
  }

  test('Deletes a bound buffer and allows repeated deletion', () {
    final buffer = cgl.createBuffer();
    cgl.bindBuffer(glArrayBuffer, buffer);
    expectDeleted(() => cgl.deleteBuffer(buffer), () => gl.isBuffer(buffer));
    expect(cgl.getParameter(glArrayBufferBinding), isNull);
  });

  test('Deletes a bound VAO without deleting its index buffer', () {
    final vao = cgl.createVertexArray();
    final buffer = cgl.createBuffer();
    cgl.bindVertexArray(vao);
    cgl.bindBuffer(glElementArrayBuffer, buffer);
    expectDeleted(
      () => cgl.deleteVertexArray(vao),
      () => gl.isVertexArray(vao),
    );
    expect(cgl.getParameter(glVertexArrayBinding), isNull);
    expectDeleted(() => cgl.deleteBuffer(buffer), () => gl.isBuffer(buffer));
  });

  test('Deletes a bound framebuffer without deleting its attachment', () {
    final texture = cgl.createTexture();
    cgl.bindTexture(glTexture2D, texture);
    cgl.texStorage2D(glTexture2D, 1, glRgba8, 2, 2);
    final framebuffer = cgl.createFramebuffer();
    cgl.bindFramebuffer(glFramebuffer, framebuffer);
    cgl.framebufferTexture2D(
      glFramebuffer,
      glColorAttachment0,
      glTexture2D,
      texture,
      0,
    );
    expect(cgl.checkFramebufferStatus(glFramebuffer), glFramebufferComplete);
    expectDeleted(
      () => cgl.deleteFramebuffer(framebuffer),
      () => gl.isFramebuffer(framebuffer),
    );
    expect(cgl.getParameter(glFramebufferBinding), isNull);
    expectDeleted(
      () => cgl.deleteTexture(texture),
      () => gl.isTexture(texture),
    );
  });

  test('Deletes a bound texture and allows repeated deletion', () {
    final texture = cgl.createTexture();
    cgl.bindTexture(glTexture2D, texture);
    expectDeleted(
      () => cgl.deleteTexture(texture),
      () => gl.isTexture(texture),
    );
    expect(cgl.getParameter(glTextureBinding2D), isNull);
  });

  test('Deletes inactive transform feedback without deleting its buffer', () {
    final transform = cgl.createTransformFeedback();
    final buffer = cgl.createBuffer();
    cgl.bindTransformFeedback(transform);
    cgl.bufferDataSetSize(glTransformFeedbackBuffer, buffer, 16, glDynamicDraw);
    cgl.bindBufferBase(glTransformFeedbackBuffer, 0, buffer);
    expectDeleted(
      () => cgl.deleteTransformFeedback(transform),
      () => gl.isTransformFeedback(transform),
    );
    expect(cgl.getParameter(glTransformFeedbackBinding), isNull);
    expectDeleted(() => cgl.deleteBuffer(buffer), () => gl.isBuffer(buffer));
  });

  test('Deletes a bound sampler and allows repeated deletion', () {
    final sampler = cgl.createSampler();
    gl.bindSampler(0, sampler);
    expectDeleted(
      () => cgl.deleteSampler(sampler),
      () => gl.isSampler(sampler),
    );
    expect(cgl.getParameter(glSamplerBinding), isNull);
  });

  test('Deletes an unused program without deleting its attached shader', () {
    final program = cgl.createProgram();
    final shader = cgl.createShader(glVertexShader);
    gl.attachShader(program, shader);
    expectDeleted(
      () => cgl.deleteProgram(program),
      () => gl.isProgram(program),
    );
    expectDeleted(() => cgl.deleteShader(shader), () => gl.isShader(shader));
  });

  for (final kind in [glVertexShader, glFragmentShader]) {
    test('Deletes an unattached shader of type $kind', () {
      final shader = cgl.createShader(kind);
      expectDeleted(() => cgl.deleteShader(shader), () => gl.isShader(shader));
    });
  }

  test(
    'Marks an attached shader for deletion until its program is deleted',
    () {
      final program = cgl.createProgram();
      final shader = cgl.createShader(glVertexShader);
      gl.attachShader(program, shader);
      expect(gl.isShader(shader), isTrue);
      expect(
        (gl.getShaderParameter(shader, glDeleteStatus) as JSBoolean).toDart,
        isFalse,
      );
      for (var i = 0; i < 2; i++) {
        cgl.deleteShader(shader);
        expect(
          (gl.getShaderParameter(shader, glDeleteStatus) as JSBoolean).toDart,
          isTrue,
        );
        expect(gl.isShader(shader), isTrue);
        expect(cgl.getError(), glNoError);
      }
      cgl.deleteProgram(program);
      expect(gl.isProgram(program), isFalse);
      expect(gl.isShader(shader), isFalse);
      expect(cgl.getError(), glNoError);
    },
  );

  test('Marks the current program for deletion until it is no longer used', () {
    final program = cgl.compileWholeProgram(_vertexSource, _fragmentSource, []);
    expect(gl.getAttachedShaders(program)!.toDart, isEmpty);
    cgl.useProgram(program);
    expect(gl.isProgram(program), isTrue);
    expect(
      (gl.getProgramParameter(program, glDeleteStatus) as JSBoolean).toDart,
      isFalse,
    );
    for (var i = 0; i < 2; i++) {
      cgl.deleteProgram(program);
      expect(
        (gl.getProgramParameter(program, glDeleteStatus) as JSBoolean).toDart,
        isTrue,
      );
      expect(gl.isProgram(program), isTrue);
      expect(
        (cgl.getParameter(glCurrentProgram) as JSObject)
            .strictEquals(program)
            .toDart,
        isTrue,
      );
      expect(cgl.getError(), glNoError);
    }
    gl.useProgram(null);
    expect(gl.isProgram(program), isFalse);
    expect(cgl.getParameter(glCurrentProgram), isNull);
    expect(cgl.getError(), glNoError);
  });
}
