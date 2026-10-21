@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:chronosgl/src/core/lib.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

web.HTMLCanvasElement _canvas() => web.HTMLCanvasElement()
  ..width = 2
  ..height = 2;

ChronosGL _context([web.HTMLCanvasElement? canvas]) {
  final cgl = ChronosGL(
    canvas ?? _canvas(),
    antialiasing: false,
    preserveDrawingBuffer: true,
  );
  addTearDown(() {
    final extension = cgl.getExtension('WEBGL_lose_context');
    if (extension != null) (extension as web.WEBGL_lose_context).loseContext();
  });
  return cgl;
}

void main() {
  test(
    'Modern canvas options and WebGL query values cross the JS boundary',
    () {
      final canvas = _canvas();
      final cgl = _context(canvas);
      final gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
      final attributes = gl.getContextAttributes()!;
      expect(attributes.alpha, isFalse);
      expect(attributes.depth, isTrue);
      expect(attributes.stencil, isTrue);
      expect(attributes.antialias, isFalse);
      expect(attributes.preserveDrawingBuffer, isTrue);
      expect(cgl.getParameter(glMaxTextureSize), isA<int>());
      expect(cgl.getParameter(glDepthWritemask), isTrue);
      expect(cgl.getParameter(glVersion), contains('WebGL 2.0'));
      cgl.viewport(1, 2, 3, 4);
      expect(cgl.getParameter(glViewport), [1, 2, 3, 4]);
      cgl.colorMask(true, false, true, false);
      expect(cgl.getParameter(glColorWritemask), [true, false, true, false]);
      expect(cgl.getParameter(glArrayBufferBinding), isNull);
      final buffer = cgl.createBuffer();
      cgl.bindBuffer(glArrayBuffer, buffer);
      final bound = cgl.getParameter(glArrayBufferBinding) as JSObject;
      expect(bound.strictEquals(buffer).toDart, isTrue);
      expect(cgl.getSupportedExtensions(), isNotEmpty);
      expect(cgl.getSupportedExtensions(), everyElement(isA<String>()));
      expect(cgl.getExtension('CHRONOSGL_nonexistent_extension'), isNull);
      expect(cgl.maxAnisotropicFilterLevel(), greaterThanOrEqualTo(1));
      expect(cgl.getError(), glNoError);
    },
  );

  test('Buffer uploads and readbacks preserve typed-data view boundaries', () {
    final cgl = _context();
    final buffer = cgl.createBuffer();
    final input = Uint16List.fromList([999, 1, 512, 65535, 999]);
    cgl.changeArrayBuffer(buffer, Uint16List.sublistView(input, 1, 4));
    final output = Uint16List.fromList([777, 0, 0, 0, 777]);
    cgl.getArrayBuffer(buffer, Uint16List.sublistView(output, 1, 4));
    expect(output, [777, 1, 512, 65535, 777]);

    final bytes = Uint8List(10)..fillRange(0, 10, 123);
    final view = ByteData.sublistView(bytes, 2, 8);
    cgl.getTransformBuffer(buffer, view);
    expect(bytes.sublist(0, 2), [123, 123]);
    expect(bytes.sublist(2, 8), Uint8List.sublistView(input, 1, 4));
    expect(bytes.sublist(8), [123, 123]);
    expect(cgl.getError(), glNoError);
  });

  test('Modern DOM textures upload, update, and read into a byte view', () {
    final cgl = _context();
    final image = _canvas();
    final paint = image.getContext('2d') as web.CanvasRenderingContext2D;
    paint.fillStyle = '#336699'.toJS;
    paint.fillRect(0, 0, 2, 2);
    final texture = ImageTexture(
      cgl,
      'canvas',
      image,
      texturePropertiesFramebuffer,
    );
    final framebuffer = Framebuffer(cgl, texture);
    expect(framebuffer.extractByteData(null, 0, 0, 1, 1), [51, 102, 153, 255]);
    paint.fillStyle = '#ff0000'.toJS;
    paint.fillRect(0, 0, 2, 2);
    texture.update();
    framebuffer.activate(0, 0, 0, 2, 2);
    final format = FramebufferFormat.fromActive(cgl);
    expect(format.format, glRgba);
    expect(format.type, glUnsignedByte);
    final output = Uint8List(24)..fillRange(0, 24, 123);
    cgl.readPixels(
      0,
      0,
      2,
      2,
      glRgba,
      glUnsignedByte,
      Uint8List.sublistView(output, 4, 20),
    );
    expect(output.sublist(0, 4), [123, 123, 123, 123]);
    expect(output.sublist(4, 20), [
      for (var i = 0; i < 4; i++) ...[255, 0, 0, 255],
    ]);
    expect(output.sublist(20), [123, 123, 123, 123]);
    expect(cgl.getError(), glNoError);
  });

  test('Float textures retain their element type and subview offsets', () {
    final cgl = _context();
    expect(cgl.getExtension('EXT_color_buffer_float'), isNotNull);
    final input = Float32List.fromList([999, 0.25, 0.5, 0.75, 1, 999]);
    final texture = TypedTextureMutable(
      cgl,
      'float',
      1,
      1,
      glRgba32f,
      texturePropertiesFramebuffer,
      glRgba,
      glFloat,
      Float32List.sublistView(input, 1, 5),
    );
    final framebuffer = Framebuffer(cgl, texture);
    final output = Float32List.fromList([777, 0, 0, 0, 0, 777]);
    framebuffer.extractFloatData(
      Float32List.sublistView(output, 1, 5),
      0,
      0,
      1,
      1,
    );
    expect(output, [777, 0.25, 0.5, 0.75, 1, 777]);
    final updated = Float32List.fromList([999, 1, 0.75, 0.5, 0.25, 999]);
    texture.updateContentPartial(
      Float32List.sublistView(updated, 1, 5),
      glRgba,
      glFloat,
      0,
      0,
      1,
      1,
    );
    expect(framebuffer.extractFloatData(null, 0, 0, 1, 1), [
      1,
      0.75,
      0.5,
      0.25,
    ]);
    expect(cgl.getError(), glNoError);
  });

  test('Pixel pack readback uses the numeric offset overload', () {
    final cgl = _context();
    cgl.clearColor(1, 0, 0, 1);
    cgl.clear(glColorBufferBit);
    final buffer = cgl.createBuffer();
    cgl.bufferDataSetSize(glPixelPackBuffer, buffer, 24, glStreamRead);
    expect(cgl.getError(), glNoError, reason: 'Allocate pixel pack buffer');
    cgl.bindBuffer(glPixelPackBuffer, buffer);
    cgl.readPixelsToBuffer(0, 0, 2, 2, glRgba, glUnsignedByte, 4);
    expect(
      cgl.getError(),
      glNoError,
      reason: 'Read pixels into pixel pack buffer',
    );
    cgl.bindBuffer(glPixelPackBuffer, null);
    final output = Uint8List(24);
    cgl.getArrayBuffer(buffer, output);
    expect(cgl.getError(), glNoError, reason: 'Read back pixel pack buffer');
    expect(output, [
      0,
      0,
      0,
      0,
      for (var i = 0; i < 4; i++) ...[255, 0, 0, 255],
      0,
      0,
      0,
      0,
    ]);
    expect(cgl.getError(), glNoError);
  });

  test(
    'Transform feedback registers JS varying names and returns GPU output',
    () {
      final cgl = _context();
      final vertex = ShaderObject('feedback-v')
        ..addAttributeVars([aPosition])
        ..addTransformVars([vPosition])
        ..setBodyWithMain([
          '$vPosition = $aPosition * 2.0;',
          'gl_Position = vec4($aPosition, 1.0);',
        ]);
      final fragment = ShaderObject('feedback-f')
        ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
      final program = cgl.compileWholeProgram(
        vertex.shader!,
        fragment.shader!,
        [vPosition],
      );
      cgl.bindVertexArray(cgl.createVertexArray());
      final input = cgl.createBuffer();
      cgl.changeArrayBuffer(input, Float32List.fromList([1, 2, 3, 4, 5, 6]));
      cgl.vertexAttribPointer(input, 0, 3, glFloat, false, 0, 0);
      cgl.enableVertexAttribArray(0, 0);
      final output = cgl.createBuffer();
      cgl.bufferDataSetSize(
        glTransformFeedbackBuffer,
        output,
        24,
        glDynamicDraw,
      );
      cgl.bindTransformFeedback(cgl.createTransformFeedback());
      cgl.bindBufferBase(glTransformFeedbackBuffer, 0, output);
      cgl.useProgram(program);
      cgl.enable(glRasterizerDiscard);
      cgl.draw(glPoints, 2, -1, 0, 0, true);
      cgl.disable(glRasterizerDiscard);
      cgl.bindBufferBase(glTransformFeedbackBuffer, 0, null);
      final result = Float32List(6);
      cgl.getTransformBuffer(output, result);
      expect(result, [2, 4, 6, 8, 10, 12]);
      expect(cgl.getError(), glNoError);
    },
  );
}
