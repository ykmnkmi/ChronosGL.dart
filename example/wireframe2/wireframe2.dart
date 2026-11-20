import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:async';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

const String meshFile = "../asset/dragon/dragon.obj";

web.HTMLInputElement gShowNormals =
    web.document.querySelector('#normals') as web.HTMLInputElement;

web.HTMLInputElement gShowWires =
    web.document.querySelector('#wires') as web.HTMLInputElement;

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
      "solid",
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
  phase.add(scene);

  final Material matWire = lifetime.own(Material("wire"))
    ..setUniform(uColor, colorYellow.toVector3());
  final Material matNorm = lifetime.own(Material("normal"))
    ..setUniform(uColor, colorBlue.toVector3());

  late Node nodeWire;
  late Node nodeNorm;

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
    nodeNorm.enabled = gShowNormals.checked;
    nodeWire.enabled = gShowWires.checked;
    phase.draw();

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  List<Future<Object>> futures = [loadRaw(meshFile)];

  Future.wait(futures).then((list) {
    if (lifetime.isDisposed) return;
    GeometryBuilder gb = importGeometryFromWavefront(list[0] as String);
    print(gb);
    GpuMesh mdWire = lifetime.own(
      uploadWireframeGeometry(meshFile, scene.program, gb),
    );
    print(mdWire);

    nodeWire = MeshNode(mdWire.name, mdWire, matWire);
    nodeWire.lookAt(vm.Vector3(100.0, 0.0, 0.0));
    scene.add(nodeWire);

    GpuMesh mdNorm = lifetime.own(
      geometryBuilderToWireframeNormals(scene.program, gb, 0.05),
    );
    nodeNorm = MeshNode(mdNorm.name, mdNorm, matNorm);
    nodeNorm.lookAt(vm.Vector3(100.0, 0.0, 0.0));
    scene.add(nodeNorm);

    // Start
    lifetime.requestAnimationFrame(onFrame);
  });
}
