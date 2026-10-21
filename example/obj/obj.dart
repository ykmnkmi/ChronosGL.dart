import 'dart:html' as html;
import 'dart:async';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String modelFile = "../ct_logo.obj";

final List<Future<Object>> gLoadables = [];

void main() {
  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  final ChronosGL cgl = ChronosGL(canvas);
  final OrbitCamera orbit = OrbitCamera(25.0, 0.0, 0.0, canvas);
  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  final RenderProgram progDemo = RenderProgram(
    "demo",
    cgl,
    demoVertexShader,
    demoFragmentShader,
  );

  late MeshData ctLogo; // we be initialized when loaded
  var future = loadRaw(modelFile)
    ..then((String content) {
      GeometryBuilder gb = importGeometryFromWavefront(content);
      ctLogo = geometryBuilderToMeshData("", progDemo, gb);
    });
  gLoadables.add(future);

  final Material material = Material("mat")
    ..setUniform(uColor, colorGray8)
    ..setUniform(uModelMatrix, vm.Matrix4.identity()..rotateX(math.pi / 2));

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    progDemo.draw(ctLogo, [perspective, material]);
    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
