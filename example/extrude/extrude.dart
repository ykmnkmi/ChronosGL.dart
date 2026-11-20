import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final web.HTMLInputElement gWidth =
    web.document.querySelector('#width') as web.HTMLInputElement;
final web.HTMLInputElement gHeight =
    web.document.querySelector('#height') as web.HTMLInputElement;
final web.HTMLInputElement gSegments =
    web.document.querySelector('#segments') as web.HTMLInputElement;

final web.HTMLSelectElement gEasingWidth =
    web.document.querySelector('#easingWidth') as web.HTMLSelectElement;
final web.HTMLSelectElement gEasingHeight =
    web.document.querySelector('#easingHeight') as web.HTMLSelectElement;
final List<vm.Vector2> gBase = contourCircle(20, 10.0);
final List<vm.Vector2> gGrad = getContourGradient(gBase);

GpuMesh makeBevelMesh(RenderProgram prog) {
  double width = gWidth.valueAsNumber + 0.0;
  double height = gHeight.valueAsNumber + 0.0;
  Easing easingWidth = mapStringToEasing[gEasingWidth.value]!;
  Easing easingHeight = mapStringToEasing[gEasingHeight.value]!;
  int segments = gSegments.valueAsNumber.toInt();
  List<vm.Vector2> supports = bevelSupportPoints(
    width,
    height,
    segments,
    widthEasing: easingWidth,
    heightEasing: easingHeight,
  );
  List<List<vm.Vector3>> strips = bevelStrips(
    gBase,
    gGrad,
    supports,
    vm.Matrix3.identity(),
  );
  GeometryBuilder gb = GeometryBuilder();
  gb.addFaces4Strips(strips, true);
  return uploadWireframeGeometry("", prog, gb);
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

  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram prog = lifetime.own(
    RenderProgram(
      "basic",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
  );

  final Material matWire = lifetime.own(Material("wire"))
    ..setUniform(uColor, colorYellow.toVector3())
    ..setUniform(uModelMatrix, vm.Matrix4.identity());

  double? lastTimeMs;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      lastTimeMs = timeMs;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = lastTimeMs == null ? 0.0 : timeMs - lastTimeMs!;
    lastTimeMs = timeMs + 0.0;
    orbit.update(elapsed / 1000.0);
    // For simplicity we create a new mesh every frame.
    GpuMesh wire = makeBevelMesh(prog);
    try {
      prog.draw(wire, [perspective, matWire]);
    } finally {
      wire.dispose();
    }

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
