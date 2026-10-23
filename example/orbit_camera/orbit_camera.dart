import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:web/web.dart' as web;

Scene makeStarScene(ChronosGL cgl, UniformGroup perspective, int num) {
  Scene scene = Scene(
    "stars",
    RenderProgram(
      "stars",
      cgl,
      pointSpritesVertexShader,
      pointSpritesFragmentShader,
    ),
    [perspective],
  );
  scene.add(Utils.makeParticles(scene.program, num));
  return scene;
}

Node makeHead(RenderProgram program) {
  MeshData sphere = shapeIcosahedron(program);
  Material headMat = Material("head")
    ..setUniform(uColor, vm.Vector3(0.94, 0.72, 0.63));
  Node head = Node("head", sphere, headMat);

  Material eyeMat = Material("eye")..setUniform(uColor, colorBlue);
  Node leftEye = Node("leftEye", sphere, eyeMat)
    ..setPos(-0.2, 0.4, -0.8)
    ..transform.scaleByDouble(0.2, 0.2, 0.2, 1.0);
  head.add(leftEye);

  Node rightEye = Node("rightEye", sphere, eyeMat)
    ..transform.scaleByDouble(0.2, 0.2, 0.2, 1.0)
    ..setPos(0.2, 0.4, -0.8);
  head.add(rightEye);

  Material noseMat = Material("nose")
    ..setUniform(uColor, vm.Vector3(0.9, 0.7, 0.6));
  Node nose = Node("nose", sphere, noseMat)
    ..transform.scaleByDouble(0.3, 0.3, 0.3, 1.0)
    ..setPos(0.0, 0.0, -0.9);
  head.add(nose);
  return head;
}

void main() {
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL(canvas);
  OrbitCamera orbit = OrbitCamera(15.0, 0.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final Scene scene = Scene(
    "objects",
    RenderProgram(
      "solid",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    [perspective],
  );

  scene.add(makeHead(scene.program));

  final RenderPhaseResizeAware phase =
      RenderPhaseResizeAware("main", cgl, canvas, perspective)
        ..add(scene)
        ..add(makeStarScene(cgl, perspective, 2000));

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    phase.draw();

    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
