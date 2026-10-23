import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:async';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String modelFile = "../ct_logo.obj";

final web.HTMLInputElement gSobel =
    web.document.querySelector('#activate') as web.HTMLInputElement;

final List<Future<Object>> gLoadables = [];

void main() {
  final StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final width = canvas.clientWidth;
  final height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;
  final ChronosGL cgl = ChronosGL(canvas);
  final OrbitCamera orbit = OrbitCamera(15.0, -45.0, 0.3, canvas);
  final Perspective perspective = Perspective(orbit, 0.1, 2520.0)
    ..adjustAspect(width, height);

  final Framebuffer screen = Framebuffer.screen(cgl);
  final Framebuffer fb = Framebuffer.defaultFramebuffer(cgl, width, height);

  final List<ShaderObject> greyShader = createPlane2GreyShader();
  final RenderProgram progGrey = RenderProgram(
    "grey",
    cgl,
    greyShader[0],
    greyShader[1],
  );

  final RenderProgram progSobel = RenderProgram(
    "ssao",
    cgl,
    sobelVertexShader,
    sobelFragmentShader,
  );

  final UniformGroup uniforms = UniformGroup("plain")
    ..setUniform(uCanvasSize, vm.Vector2(0.0 + width, 0.0 + height))
    ..setUniform(uDepthMap, fb.depthTexture!)
    ..setUniform(uTexture, fb.colorTexture!);

  final MeshData unitQuad = shapeQuad(progSobel, 1);
  late MeshData ctLogo;

  var future = loadRaw(modelFile)
    ..then((String content) {
      GeometryBuilder gb = importGeometryFromWavefront(content);
      ctLogo = geometryBuilderToMeshData("", progGrey, gb);
    });
  gLoadables.add(future);

  Material material = Material("mat")
    ..setUniform(uModelMatrix, vm.Matrix4.identity()..rotateX(math.pi / 2));

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    if (gSobel.checked) {
      // Draw objects into fb
      fb.activate(glClearAll, 0, 0, width, height);
      progGrey.draw(ctLogo, [perspective, material]);
      // Apply sobel to fb and show result on screen
      screen.activate(glClearAll, 0, 0, width, height);
      progSobel.draw(unitQuad, [uniforms]);
    } else {
      progGrey.draw(ctLogo, [perspective, material]);
    }
    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
