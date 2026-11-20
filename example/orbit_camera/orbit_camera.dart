import 'dart:math' as math;

import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

RenderBatch makeStarScene(ChronosGL cgl, UniformGroup perspective, int num) {
  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "stars",
      lifetime.own(
        RenderProgram.create(
          name: "stars",
          context: cgl,
          vertexShader: pointSpritesVertexShader,
          fragmentShader: pointSpritesFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  scene.add(makeParticles(scene.program, num, random: math.Random()));
  return scene;
}

Node makeHead(RenderProgram program) {
  GpuMesh sphere = lifetime.own(shapeIcosahedron(program));
  Material headMat = lifetime.own(Material("head"))
    ..setUniform(uColor, vm.Vector3(0.94, 0.72, 0.63));
  Node head = MeshNode("head", sphere, headMat);

  Material eyeMat = lifetime.own(Material("eye"))
    ..setUniform(uColor, colorBlue.toVector3());
  Node leftEye = MeshNode("leftEye", sphere, eyeMat)
    ..setPos(-0.2, 0.4, -0.8)
    ..transform.scaleByDouble(0.2, 0.2, 0.2, 1.0);
  head.add(leftEye);

  Node rightEye = MeshNode("rightEye", sphere, eyeMat)
    ..transform.scaleByDouble(0.2, 0.2, 0.2, 1.0)
    ..setPos(0.2, 0.4, -0.8);
  head.add(rightEye);

  Material noseMat = lifetime.own(Material("nose"))
    ..setUniform(uColor, vm.Vector3(0.9, 0.7, 0.6));
  Node nose = MeshNode("nose", sphere, noseMat)
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
  ChronosGL cgl = ChronosGL.fromCanvas(canvas);
  final camera = PerspectiveCamera(near: 0.1, far: 1000);
  final controls = lifetime.own(
    OrbitControls.forCamera(camera: camera, eventTarget: canvas, radius: 15),
  );
  final perspective = CameraUniforms(camera);

  final RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "objects",
      lifetime.own(
        RenderProgram.create(
          name: "solid",
          context: cgl,
          vertexShader: solidColorVertexShader,
          fragmentShader: solidColorFragmentShader,
        ),
      ),
      [perspective],
    ),
  );

  scene.add(makeHead(scene.program));

  final phase = lifetime.ownPass(RenderPass("main", cgl))
    ..add(scene)
    ..add(makeStarScene(cgl, perspective, 2000));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

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

    lifetime.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
