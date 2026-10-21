import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';

void main() {
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  ChronosGL cgl = ChronosGL(canvas);

  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);
  double d = 20.0;

  RenderProgram prog = RenderProgram(
    "textured",
    cgl,
    solidColorVertexShader,
    solidColorFragmentShader,
  );

  Orthographic orthographic = Orthographic(orbit, -d, d, -d, -d, 100.0);
  RenderPhase phaseOrthograhic = RenderPhase("shadow", cgl);
  Scene sceneOrthographic = Scene("objects", prog, [orthographic]);
  phaseOrthograhic.add(sceneOrthographic);

  Perspective perspective = Perspective(orbit, 0.1, 1000.0);
  RenderPhase phasePerspective = RenderPhase("perspective", cgl);
  phasePerspective.clearColorBuffer = false;
  Scene scenePerspective = Scene("objects", prog, [perspective]);
  phasePerspective.add(scenePerspective);

  final Material mat1 = Material("mat1")..setUniform(uColor, colorBlue);
  final Material mat2 = Material("mat2")..setUniform(uColor, colorRed);
  final Material mat3 = Material("mat3")..setUniform(uColor, colorGreen);
  final Material mat4 = Material("mat4")..setUniform(uColor, colorCyan);
  final Material mat5 = Material("plane")..setUniform(uColor, colorGray8);

  final List<Node> nodes = [
    Node("sphere", shapeIcosahedron(prog, subdivisions: 3), mat1)
      ..setPos(0.0, 0.0, 0.0),
    Node("cube", shapeCube(prog), mat2)..setPos(-5.0, 0.0, -5.0),
    Node("cylinder", shapeCylinder(prog, 3.0, 6.0, 2.0, 32), mat3)
      ..setPos(5.0, 0.0, -5.0),
    Node("torus", shapeTorusKnot(prog, radius: 1.0, tubeRadius: 0.4), mat4)
      ..setPos(5.0, 0.0, 5.0),
    Node("cube", shapeCube(prog, x: 20.0, y: 0.1, z: 20.0), mat5)
      ..setPos(0.0, -10.0, 0.0),
  ];

  for (Node n in nodes) {
    sceneOrthographic.add(n);
    scenePerspective.add(n);
  }

  // This sets the viewports among other things
  void resolutionChange(html.Event? ev) {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    canvas.width = w;
    canvas.height = h;
    print("size change $w $h");
    w = w ~/ 2;
    perspective.adjustAspect(w, h);
    orthographic.adjustAspect(w, h);
    phaseOrthograhic.viewPortW = w;
    phaseOrthograhic.viewPortH = h;
    phasePerspective.viewPortW = w;
    phasePerspective.viewPortH = h;
    phaseOrthograhic.viewPortX = phasePerspective.viewPortW;
  }

  resolutionChange(null);
  html.window.onResize.listen(resolutionChange);

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    //orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    phaseOrthograhic.draw();
    phasePerspective.draw();
    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  animate(0.0);
}
