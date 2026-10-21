import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';

import 'package:vector_math/vector_math.dart' as vm;

final html.InputElement gWidth =
    html.document.querySelector('#width') as html.InputElement;
final html.InputElement gHeight =
    html.document.querySelector('#height') as html.InputElement;
final html.InputElement gSegments =
    html.document.querySelector('#segments') as html.InputElement;

final html.SelectElement gEasingWidth =
    html.document.querySelector('#easingWidth') as html.SelectElement;
final html.SelectElement gEasingHeight =
    html.document.querySelector('#easingHeight') as html.SelectElement;
final List<vm.Vector2> gBase = contourCircle(20, 10.0);
final List<vm.Vector2> gGrad = getContourGradient(gBase);

MeshData makeBevelMesh(RenderProgram prog) {
  double width = gWidth.valueAsNumber! + 0.0;
  double height = gHeight.valueAsNumber! + 0.0;
  Easing easingWidth = mapStringToEasing[gEasingWidth.value]!;
  Easing easingHeight = mapStringToEasing[gEasingHeight.value]!;
  int segments = gSegments.valueAsNumber!.toInt();
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
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
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
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    // For simplicity we create a new mesh every frame.
    MeshData wire = makeBevelMesh(prog);
    orbit.animate(elapsed);
    prog.draw(wire, [perspective, matWire]);

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  animate(0.0);
}
