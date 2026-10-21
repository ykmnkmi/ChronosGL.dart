import 'dart:html' as html;
import 'dart:async';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';

const String meshFile = "../asset/dragon/dragon.obj";

html.InputElement gShowNormals =
    html.document.querySelector('#normals') as html.InputElement;

html.InputElement gShowWires =
    html.document.querySelector('#wires') as html.InputElement;

void main() {
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  ChronosGL cgl = ChronosGL(canvas, faceCulling: true);

  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);
  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );
  Scene scene = Scene(
    "solid",
    RenderProgram(
      "solid",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    [perspective],
  );
  phase.add(scene);

  final Material matWire = Material("wire")..setUniform(uColor, colorYellow);
  final Material matNorm = Material("normal")..setUniform(uColor, colorBlue);

  late Node nodeWire;
  late Node nodeNorm;

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    nodeNorm.enabled = gShowNormals.checked!;
    nodeWire.enabled = gShowWires.checked!;
    phase.draw();

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs);
  }

  List<Future<Object>> futures = [loadRaw(meshFile)];

  Future.wait(futures).then((list) {
    GeometryBuilder gb = importGeometryFromWavefront(list[0] as String);
    print(gb);
    MeshData mdWire = geometryBuilderToMeshDataWireframe(
      meshFile,
      scene.program,
      gb,
    );
    print(mdWire);

    nodeWire = Node(mdWire.name, mdWire, matWire);
    nodeWire.lookAt(vm.Vector3(100.0, 0.0, 0.0));
    scene.add(nodeWire);

    MeshData mdNorm = geometryBuilderToWireframeNormals(
      scene.program,
      gb,
      0.05,
    );
    nodeNorm = Node(mdNorm.name, mdNorm, matNorm);
    nodeNorm.lookAt(vm.Vector3(100.0, 0.0, 0.0));
    scene.add(nodeNorm);

    // Start
    animate(0.0);
  });
}
