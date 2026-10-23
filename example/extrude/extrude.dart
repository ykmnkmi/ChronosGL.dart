import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';

import 'package:vector_math/vector_math.dart' as vm;

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

MeshData makeBevelMesh(RenderProgram prog) {
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
  return geometryBuilderToMeshDataWireframe("", prog, gb);
}

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL(canvas);

  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);
  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );
  final RenderProgram prog = RenderProgram(
    "basic",
    cgl,
    solidColorVertexShader,
    solidColorFragmentShader,
  );

  final Material matWire = Material("wire")
    ..setUniform(uColor, colorYellow)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    // For simplicity we create a new mesh every frame.
    MeshData wire = makeBevelMesh(prog);
    orbit.animate(elapsed);
    prog.draw(wire, [perspective, matWire]);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
