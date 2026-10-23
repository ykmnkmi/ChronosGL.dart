import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

// TODO: the 2torusknot cannot be seen through the other objects -why

final web.HTMLInputElement gOpaque =
    web.document.querySelector('#opaque') as web.HTMLInputElement;

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
    "wireframe",
    RenderProgram("main", cgl, wireframeVertexShader, wireframeFragmentShader),
    [perspective],
  );
  phase.add(scene);

  final Material matWireframe = Material("wire")
    ..setUniform(uThickness, 2.0)
    ..setUniform(uColorAlpha, vm.Vector4(1.0, 1.0, 0.0, 1.0))
    ..setUniform(uColorAlpha2, vm.Vector4(0.0, 0.0, 0.0, 0.5));

  {
    GeometryBuilder gb = icosahedronGeometry(subdivisions: 2)
      ..generateWireframeCenters();
    Node ico = Node(
      "sphere",
      geometryBuilderToMeshData("icosahedron", scene.program, gb),
      matWireframe,
    )..setPos(0.0, 0.0, 0.0);
    scene.add(ico);
  }

  {
    GeometryBuilder gb = cubeGeometry()..generateWireframeCenters();
    Node cube = Node(
      "cube",
      geometryBuilderToMeshData("cube", scene.program, gb),
      matWireframe,
    )..setPos(-5.0, 0.0, -5.0);
    scene.add(cube);
  }

  {
    GeometryBuilder gb = wedgeGeometry()..generateWireframeCenters();
    Node wedge = Node(
      "wedge",
      geometryBuilderToMeshData("wedge", scene.program, gb),
      matWireframe,
    )..setPos(0.0, -5.0, 0.0);
    scene.add(wedge);
  }

  {
    GeometryBuilder gb = cylinderGeometryWireframeFriendly(3.0, 4.0, 2.0, 16)
      ..generateWireframeCenters();
    Node cyl = Node(
      "cylinder",
      geometryBuilderToMeshData("cylinder", scene.program, gb),
      matWireframe,
    )..setPos(5.0, 0.0, -5.0);
    scene.add(cyl);
  }

  {
    GeometryBuilder gb = quadGeometry(2)..generateWireframeCenters();
    Node quad = Node(
      "quad",
      geometryBuilderToMeshData("quad", scene.program, gb),
      matWireframe,
    )..setPos(-5.0, 0.0, 5.0);
    scene.add(quad);
  }

  {
    GeometryBuilder gb = torusKnotGeometryWireframeFriendly(
      radius: 1.0,
      tubeRadius: 0.4,
    )..generateWireframeCenters();
    Node torus = Node(
      "torus",
      geometryBuilderToMeshData("torus", scene.program, gb),
      matWireframe,
    )..setPos(5.0, 0.0, 5.0);
    scene.add(torus);
  }

  {
    GeometryBuilder gb = torusKnotGeometryTriangularWireframeFriendly(
      radius: 1.0,
      tubeRadius: 0.4,
    )..generateWireframeCenters();
    Node torus = Node(
      "torus",
      geometryBuilderToMeshData("torus", scene.program, gb),
      matWireframe,
    )..setPos(0.0, 5.0, 0.0);
    scene.add(torus);
  }

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    matWireframe.forceUniform(
      cBlendEquation,
      gOpaque.checked ? blendEquationNone : blendEquationStandard,
    );
    phase.draw();

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
