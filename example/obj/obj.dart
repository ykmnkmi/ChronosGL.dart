import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:async';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/shaders.dart';

import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

const String modelFile = "../ct_logo.obj";

final List<Future<Object>> gLoadables = [];

void main() {
  final FpsPanel fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final ChronosGL cgl = ChronosGL.fromCanvas(canvas);
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  final CameraUniforms perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram progDemo = lifetime.own(
    RenderProgram.create(
      name: "demo",
      context: cgl,
      vertexShader: demoVertexShader,
      fragmentShader: demoFragmentShader,
    ),
  );

  late GpuMesh ctLogo; // we be initialized when loaded
  var future = loadRaw(modelFile)
    ..then((String content) {
      if (lifetime.isDisposed) return;
      GeometryBuilder gb = importGeometryFromWavefront(content);
      ctLogo = lifetime.own(uploadGeometry("", progDemo, gb));
    });
  gLoadables.add(future);

  final Material material = lifetime.own(Material("mat"))
    ..setUniform(uColor, colorGray8.toVector3())
    ..setUniform(uModelMatrix, vm.Matrix4.identity()..rotateX(math.pi / 2));

  double lastTimeMs = 0.0;
  bool firstFrame = true;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      firstFrame = true;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000;
    orbit.update(elapsed / 1000);
    progDemo.draw(ctLogo, [perspective, material]);
    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    if (lifetime.isDisposed) return;
    lifetime.requestAnimationFrame(onFrame);
  });
}
