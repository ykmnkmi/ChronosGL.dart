import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:async';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';

const String meshFile = "../asset/dragon/dragon.obj";

web.HTMLInputElement gShowNormals =
    web.document.querySelector('#normals') as web.HTMLInputElement;

web.HTMLInputElement gShowWires =
    web.document.querySelector('#wires') as web.HTMLInputElement;

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
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
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    nodeNorm.enabled = gShowNormals.checked;
    nodeWire.enabled = gShowWires.checked;
    phase.draw();

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

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
