import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

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

  final camera = PerspectiveCamera(near: 0.1, far: 1000);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25,
      azimuth: 10,
    ),
  );
  double d = 20.0;

  RenderProgram prog = lifetime.own(
    RenderProgram.create(
      name: "textured",
      context: cgl,
      vertexShader: solidColorVertexShader,
      fragmentShader: solidColorFragmentShader,
    ),
  );

  final orthographicCamera = OrthographicCamera(
    left: -d,
    right: d,
    bottom: -d,
    top: d,
    near: -d,
    far: 100,
  );
  final orthographic = CameraUniforms(orthographicCamera);
  RenderPass phaseOrthograhic = lifetime.ownPass(RenderPass("shadow", cgl));
  RenderBatch sceneOrthographic = lifetime.ownBatch(
    RenderBatch("objects", prog, [orthographic]),
  );
  phaseOrthograhic.add(sceneOrthographic);

  final perspective = CameraUniforms(camera);
  RenderPass phasePerspective = lifetime.ownPass(
    RenderPass("perspective", cgl),
  );
  phasePerspective.clearColorBuffer = false;
  RenderBatch scenePerspective = lifetime.ownBatch(
    RenderBatch("objects", prog, [perspective]),
  );
  phasePerspective.add(scenePerspective);

  final Material mat1 = lifetime.own(Material("mat1"))
    ..setUniform(uColor, colorBlue.toVector3());
  final Material mat2 = lifetime.own(Material("mat2"))
    ..setUniform(uColor, colorRed.toVector3());
  final Material mat3 = lifetime.own(Material("mat3"))
    ..setUniform(uColor, colorGreen.toVector3());
  final Material mat4 = lifetime.own(Material("mat4"))
    ..setUniform(uColor, colorCyan.toVector3());
  final Material mat5 = lifetime.own(Material("plane"))
    ..setUniform(uColor, colorGray8.toVector3());

  final List<Node> nodes = [
    MeshNode(
      "sphere",
      lifetime.own(shapeIcosahedron(prog, subdivisions: 3)),
      mat1,
    )..setPos(0.0, 0.0, 0.0),
    MeshNode("cube", lifetime.own(shapeCube(prog)), mat2)
      ..setPos(-5.0, 0.0, -5.0),
    MeshNode(
      "cylinder",
      lifetime.own(shapeCylinder(prog, 3.0, 6.0, 2.0, 32)),
      mat3,
    )..setPos(5.0, 0.0, -5.0),
    MeshNode(
      "torus",
      lifetime.own(shapeTorusKnot(prog, radius: 1.0, tubeRadius: 0.4)),
      mat4,
    )..setPos(5.0, 0.0, 5.0),
    MeshNode(
      "cube",
      lifetime.own(shapeCube(prog, x: 20.0, y: 0.1, z: 20.0)),
      mat5,
    )..setPos(0.0, -10.0, 0.0),
  ];

  for (Node n in nodes) {
    sceneOrthographic.add(n);
    scenePerspective.add(n);
  }

  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phasePerspective,
    ),
  );
  bool updateViewports() {
    if (!viewport.update()) return false;
    final width = viewport.drawingBufferWidthPixels ~/ 2;
    final height = viewport.drawingBufferHeightPixels;
    if (width == 0 || height == 0) return false;
    viewport.setViewport(width: width, height: height);
    orthographicCamera.setProjection(
      left: -d,
      right: d,
      bottom: -d,
      top: -d + 2 * d * height / width,
      near: -d,
      far: 100,
    );
    phaseOrthograhic.viewPortX = width;
    phaseOrthograhic.viewPortW = width;
    phaseOrthograhic.viewPortH = height;
    return true;
  }

  double lastTimeMs = 0.0;
  bool firstFrame = true;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!updateViewports()) {
      firstFrame = true;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    //orbit.azimuth += 0.001;
    orbit.update(elapsed / 1000);
    orthographicCamera.setPositionFromVector(camera.worldPosition);
    orthographicCamera.setRotation(camera.worldRotation);
    phaseOrthograhic.draw();
    phasePerspective.draw();
    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
