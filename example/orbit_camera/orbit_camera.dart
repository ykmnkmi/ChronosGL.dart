import 'dart:math' as math;

import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

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
  scene.add(makeParticles(scene.program, num, random: math.Random()));
  return scene;
}

Node makeHead(RenderProgram program) {
  MeshData sphere = shapeIcosahedron(program);
  Material headMat = Material("head")
    ..setUniform(uColor, vm.Vector3(0.94, 0.72, 0.63));
  Node head = Node("head", sphere, headMat);

  Material eyeMat = Material("eye")..setUniform(uColor, colorBlue.toVector3());
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
  canvas.tabIndex = 0;
  canvas.focus();
  ChronosGL cgl = ChronosGL(canvas);
  final camera = PerspectiveCamera(near: 0.1, far: 1000);
  final controls = OrbitControls(camera, canvas, radius: 15);
  final perspective = CameraUniforms(camera);

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

  final phase = RenderPhase("main", cgl)
    ..add(scene)
    ..add(makeStarScene(cgl, perspective, 2000));
  final viewport = CanvasViewport(cgl, canvas, camera, renderPhase: phase);

  double? lastTimeMs;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    final deltaSeconds = lastTimeMs == null
        ? 0.0
        : (timeMs - lastTimeMs!) / 1000;
    lastTimeMs = timeMs;
    controls.azimuth += 0.06 * deltaSeconds;
    controls.update(deltaSeconds);
    if (viewport.update()) phase.draw();

    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  web.window.requestAnimationFrame(onFrame);
}
