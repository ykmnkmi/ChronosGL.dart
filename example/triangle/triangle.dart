import 'package:chronosgl/chronosgl.dart';

import 'dart:html' as html;
import 'dart:math' as math;

Node triangle(RenderProgram program) {
  final Material mat1 = Material("mat1")..setUniform(uColor, colorBlue);

  final Material mat2 = Material("mat2")..setUniform(uColor, colorRed);

  final Material mat3 = Material("mat3")..setUniform(uColor, colorGreen);

  double thickness = 3.0;
  double length = 5.0 * thickness;

  Node side1 = Node(
    "side1",
    shapeCube(program, x: length, y: thickness, z: thickness),
    mat1,
  )..setPos(-thickness, 0.0, 0.0);

  Node side2 = Node(
    "side2",
    shapeCube(program, x: thickness, y: thickness, z: length),
    mat2,
  )..setPos(-length, 0.0, length + thickness);

  double length3 = length - thickness;
  Node side3a = Node(
    "side3a",
    shapeCube(program, x: thickness, y: length3, z: thickness),
    mat3,
  )..setPos(length, length3 - 1 * thickness, 0.0);

  Node side3b =
      Node(
          "side3b",
          shapeWedge(program, x: thickness, y: thickness, z: thickness),
          mat3,
        )
        ..rotY(math.pi)
        ..setPos(length, length + length3 - thickness, 0.0);

  return Node.container("triangle")
    ..add(side1)
    ..add(side2)
    ..add(side3a)
    ..add(side3b)
    ..moveDown(20.0);
}

void main() {
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  ChronosGL cgl = ChronosGL(canvas);

  OrbitCamera orbit = OrbitCamera(20.0, 0.0, 0.0, canvas);
  double d = 40.0;
  Orthographic orthographic = Orthographic(orbit, -d, d, -d, -d, 100.0);
  RenderPhase phase = RenderPhase("shadow", cgl);

  Scene scene = Scene(
    "objects",
    RenderProgram(
      "textured",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    [orthographic],
  );
  phase.add(scene);

  scene.add(triangle(scene.program));

  void resolutionChange(html.Event? ev) {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    canvas.width = w;
    canvas.height = h;
    print("size change $w $h");
    orthographic.adjustAspect(w, h);
    phase.viewPortW = w;
    phase.viewPortH = h;
  }

  resolutionChange(null);
  html.window.onResize.listen(resolutionChange);

  // 35deg is slightly too large.
  // Need to find a math reference for actual real angle.
  // E.g.: http://www.cse.ust.hk/~pang/papers/Impossible_Figures_ToG.pdf
  orbit.polar = 35.0 * math.pi / 180.0;
  orbit.azimuth = -45.0 * math.pi / 180.0;
  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    //orbit.azimuth += 0.001;
    //orbit.rotZ(0.001);
    orbit.animate(elapsed);
    orbit.roll += 0.01;
    double polar = orbit.polar * 180.0 / math.pi;
    double azimuth = orbit.azimuth * 180.0 / math.pi;
    phase.draw();

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs, "$polar<br>$azimuth");
  }

  animate(0.0);
}
