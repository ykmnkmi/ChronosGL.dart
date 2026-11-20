import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

// TODO: the 2torusknot cannot be seen through the other objects -why

final web.HTMLInputElement gOpaque =
    web.document.querySelector('#opaque') as web.HTMLInputElement;

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
  ChronosGL cgl = ChronosGL.fromCanvas(canvas, faceCulling: true);

  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );
  CameraUniforms perspective = CameraUniforms(camera);
  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "wireframe",
      lifetime.own(
        RenderProgram.create(
          name: "main",
          context: cgl,
          vertexShader: wireframeVertexShader,
          fragmentShader: wireframeFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  phase.add(scene);

  final Material matWireframe = lifetime.own(Material("wire"))
    ..setUniform(uThickness, 2.0)
    ..setUniform(uColorAlpha, vm.Vector4(1.0, 1.0, 0.0, 1.0))
    ..setUniform(uColorAlpha2, vm.Vector4(0.0, 0.0, 0.0, 0.5));

  {
    GeometryBuilder gb = icosahedronGeometry(subdivisions: 2)
      ..generateWireframeCenters();
    Node ico = MeshNode(
      "sphere",
      lifetime.own(uploadGeometry("icosahedron", scene.program, gb)),
      matWireframe,
    )..setPos(0.0, 0.0, 0.0);
    scene.add(ico);
  }

  {
    GeometryBuilder gb = cubeGeometry()..generateWireframeCenters();
    Node cube = MeshNode(
      "cube",
      lifetime.own(uploadGeometry("cube", scene.program, gb)),
      matWireframe,
    )..setPos(-5.0, 0.0, -5.0);
    scene.add(cube);
  }

  {
    GeometryBuilder gb = wedgeGeometry()..generateWireframeCenters();
    Node wedge = MeshNode(
      "wedge",
      lifetime.own(uploadGeometry("wedge", scene.program, gb)),
      matWireframe,
    )..setPos(0.0, -5.0, 0.0);
    scene.add(wedge);
  }

  {
    GeometryBuilder gb = cylinderGeometryWireframeFriendly(3.0, 4.0, 2.0, 16)
      ..generateWireframeCenters();
    Node cyl = MeshNode(
      "cylinder",
      lifetime.own(uploadGeometry("cylinder", scene.program, gb)),
      matWireframe,
    )..setPos(5.0, 0.0, -5.0);
    scene.add(cyl);
  }

  {
    GeometryBuilder gb = quadGeometry(2)..generateWireframeCenters();
    Node quad = MeshNode(
      "quad",
      lifetime.own(uploadGeometry("quad", scene.program, gb)),
      matWireframe,
    )..setPos(-5.0, 0.0, 5.0);
    scene.add(quad);
  }

  {
    GeometryBuilder gb = torusKnotGeometryWireframeFriendly(
      radius: 1.0,
      tubeRadius: 0.4,
    )..generateWireframeCenters();
    Node torus = MeshNode(
      "torus",
      lifetime.own(uploadGeometry("torus", scene.program, gb)),
      matWireframe,
    )..setPos(5.0, 0.0, 5.0);
    scene.add(torus);
  }

  {
    GeometryBuilder gb = torusKnotGeometryTriangularWireframeFriendly(
      radius: 1.0,
      tubeRadius: 0.4,
    )..generateWireframeCenters();
    Node torus = MeshNode(
      "torus",
      lifetime.own(uploadGeometry("torus", scene.program, gb)),
      matWireframe,
    )..setPos(0.0, 5.0, 0.0);
    scene.add(torus);
  }

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
    matWireframe.forceUniform(
      cBlendEquation,
      gOpaque.checked ? blendEquationNone : blendEquationStandard,
    );
    phase.draw();

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
