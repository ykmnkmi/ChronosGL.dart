import 'dart:html' as html;
import 'dart:async';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String modelFile = "../ct_logo.obj";

final List<Future<Object>> gLoadables = [];

final html.InputElement gSSAO =
    html.document.querySelector('#activate') as html.InputElement;

void main() {
  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
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

  final RenderProgram progSolid = RenderProgram(
    "solid",
    cgl,
    solidColorVertexShader,
    solidColorFragmentShader,
  );

  final RenderProgram progSSAO = RenderProgram(
    "ssao",
    cgl,
    ssaoVertexShader,
    ssaoFragmentShader,
  );

  final UniformGroup uniforms = UniformGroup("plain")
    ..setUniform(uCameraNear, 0.1)
    ..setUniform(uCameraFar, 2529.0)
    ..setUniform(uCanvasSize, vm.Vector2(0.0 + width, 0.0 + height))
    ..setUniform(uDepthMap, fb.depthTexture!)
    ..setUniform(uTexture, fb.colorTexture!);

  final MeshData unitQuad = shapeQuad(progSSAO, 1);

  late MeshData ctLogo;
  var future = loadRaw(modelFile)
    ..then((String content) {
      GeometryBuilder gb = importGeometryFromWavefront(content);
      ctLogo = geometryBuilderToMeshData("", progSolid, gb);
    });
  gLoadables.add(future);

  Material material = Material("mat")
    ..setUniform(uColor, colorGray8)
    ..setUniform(uModelMatrix, vm.Matrix4.identity()..rotateX(math.pi / 2));

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    if (gSSAO.checked!) {
      fb.activate(glClearAll, 0, 0, width, height);
      progSolid.draw(ctLogo, [perspective, material]);
      screen.activate(glClearAll, 0, 0, width, height);
      progSSAO.draw(unitQuad, [uniforms]);
    } else {
      progSolid.draw(ctLogo, [perspective, material]);
    }

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
