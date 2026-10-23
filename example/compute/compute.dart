import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';

const int kDim = 500;

final ShaderObject computeVertexShader = ShaderObject("computeVertexShader")
  ..addAttributeVars([aPosition])
  ..setBody([nullVertexShaderString]);

final ShaderObject computeFragmentShader = ShaderObject("computeFragmentShader")
  ..setBody([
    """
void main() { 
    $oFragColor.b = gl_FragCoord.x / $kDim.0;
    $oFragColor.g = gl_FragCoord.y / $kDim.0;
    $oFragColor.r = 0.0;
}
    """,
  ]);

String extractAndSummarizeBytes(Framebuffer fb, int w, int h) {
  Uint8List buf = fb.extractByteData(null, 0, 0, w, h);
  int channels = buf.length ~/ (w * h);
  print("Buffer length: ${buf.length} channels: $channels");
  int r = 0;
  int g = 0;
  int b = 0;
  for (int i = 0; i < buf.length; i += channels) {
    r += buf[i + 0];
    g += buf[i + 1];
    b += buf[i + 2];
  }
  return "${r / (w * h)} ${g / (w * h)} ${b / (w * h)}";
}

String extractAndSummarizeFloat(Framebuffer fb, int w, int h) {
  Float32List buf = fb.extractFloatData(null, 0, 0, w, h);
  int channels = buf.length ~/ (w * h);
  print("Buffer length: ${buf.length} channels: $channels");
  double r = 0.0;
  double g = 0.0;
  double b = 0.0;
  double a = 0.0;
  for (int i = 0; i < buf.length; i += channels) {
    r += buf[i + 0];
    g += buf[i + 1];
    b += buf[i + 2];
    a += buf[i + 3];
  }

  return "${r / (w * h)} ${g / (w * h)} ${b / (w * h)} ${a / (w * h)}";
}

void main() {
  final web.HTMLDivElement results =
      web.document.querySelector('#results') as web.HTMLDivElement;

  // The canvas is what we render the 3d scene into.
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  canvas
    ..width = kDim
    ..height = kDim;

  final ChronosGL cgl = ChronosGL(canvas);

  final RenderProgram program = RenderProgram(
    "program",
    cgl,
    computeVertexShader,
    computeFragmentShader,
  );

  final MeshData unitQuad = shapeQuad(program, 1);

  {
    final Framebuffer fb = Framebuffer.defaultFramebuffer(cgl, kDim, kDim);

    results.insertAdjacentHTML(
      'beforeend',
      '<h3>Drawing into default format FB</h3>'.toJS,
    );
    fb.activate(glClearAll, 0, 0, kDim, kDim);
    program.draw(unitQuad, []);
    results.appendChild(
      web.Text('${extractAndSummarizeBytes(fb, kDim, kDim)}\n'),
    );
  }

  {
    results.insertAdjacentHTML(
      'beforeend',
      '<h3>Drawing into float format FB</h3>'.toJS,
    );
    var ext = cgl.getExtension("EXT_color_buffer_float");
    if (ext == null) {
      results.appendChild(
        web.Text('extension not available: EXT_color_buffer_float'),
      );
      return;
    }
    TypedTexture tex = TypedTexture(
      cgl,
      "float",
      kDim,
      kDim,
      glRgba32f,
      texturePropertiesFramebuffer,
    );

    Framebuffer fb = Framebuffer(cgl, tex);
    fb.activate(glClearAll, 0, 0, kDim, kDim);
    program.draw(unitQuad, []);
    results.appendChild(
      web.Text('${extractAndSummarizeFloat(fb, kDim, kDim)}\n'),
    );
  }
}
