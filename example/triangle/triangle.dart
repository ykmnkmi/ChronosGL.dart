import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:web/web.dart' as web;

import 'dart:math' as math;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

Node triangle(RenderProgram program) {
  final Material mat1 = lifetime.own(Material("mat1"))
    ..setUniform(uColor, colorBlue.toVector3());

  final Material mat2 = lifetime.own(Material("mat2"))
    ..setUniform(uColor, colorRed.toVector3());

  final Material mat3 = lifetime.own(Material("mat3"))
    ..setUniform(uColor, colorGreen.toVector3());

  double thickness = 3.0;
  double length = 5.0 * thickness;

  Node side1 = MeshNode(
    "side1",
    lifetime.own(shapeCube(program, x: length, y: thickness, z: thickness)),
    mat1,
  )..setPos(-thickness, 0.0, 0.0);

  Node side2 = MeshNode(
    "side2",
    lifetime.own(shapeCube(program, x: thickness, y: thickness, z: length)),
    mat2,
  )..setPos(-length, 0.0, length + thickness);

  double length3 = length - thickness;
  Node side3a = MeshNode(
    "side3a",
    lifetime.own(shapeCube(program, x: thickness, y: length3, z: thickness)),
    mat3,
  )..setPos(length, length3 - 1 * thickness, 0.0);

  Node side3b =
      MeshNode(
          "side3b",
          lifetime.own(
            shapeWedge(program, x: thickness, y: thickness, z: thickness),
          ),
          mat3,
        )
        ..rotY(math.pi)
        ..setPos(length, length + length3 - thickness, 0.0);

  return GroupNode("triangle")
    ..add(side1)
    ..add(side2)
    ..add(side3a)
    ..add(side3b)
    ..moveDown(20.0);
}

void main() {
  FpsPanel fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL.fromCanvas(canvas);

  const d = 40.0;
  final camera = OrthographicCamera(
    left: -d,
    right: d,
    bottom: -d,
    top: d,
    near: -d,
    far: 100,
  );
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(camera: camera, eventTarget: canvas, radius: 20),
  );
  final orthographic = CameraUniforms(camera);
  RenderPass phase = lifetime.ownPass(RenderPass("shadow", cgl));

  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "objects",
      lifetime.own(
        RenderProgram.create(
          name: "textured",
          context: cgl,
          vertexShader: solidColorVertexShader,
          fragmentShader: solidColorFragmentShader,
        ),
      ),
      [orthographic],
    ),
  );
  phase.add(scene);

  scene.add(triangle(scene.program));

  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

  // 35deg is slightly too large.
  // Need to find a math reference for actual real angle.
  // E.g.: http://www.cse.ust.hk/~pang/papers/Impossible_Figures_ToG.pdf
  orbit.polar = 35.0 * math.pi / 180.0;
  orbit.azimuth = -45.0 * math.pi / 180.0;
  double lastTimeMs = 0.0;
  bool firstFrame = true;
  double roll = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      firstFrame = true;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    camera.setProjection(
      left: -d,
      right: d,
      bottom: -d,
      top:
          -d +
          2 * d * viewport.viewportHeightPixels / viewport.viewportWidthPixels,
      near: -d,
      far: 100,
    );
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    //orbit.azimuth += 0.001;
    //orbit.rotZ(0.001);
    orbit.update(elapsed / 1000);
    roll += 0.6 * elapsed / 1000;
    camera.setRotation(
      camera.worldRotation * vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), roll),
    );
    double polar = orbit.polar * 180.0 / math.pi;
    double azimuth = orbit.azimuth * 180.0 / math.pi;
    phase.draw();

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs, "$polar<br>$azimuth");
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
