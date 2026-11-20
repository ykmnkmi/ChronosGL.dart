import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

Map<String, vm.Vector3> shapeToColor = {
  "sphere": colorCyan.toVector3(),
  "cube": colorRed.toVector3(),
  "cylinder": colorGreen.toVector3(),
  "quad": colorMagenta.toVector3(),
  "torus": colorBlue.toVector3(),
};

void main() {
  final web.HTMLDivElement info =
      web.document.querySelector('#info') as web.HTMLDivElement;

  final FpsPanel fps = lifetime.own(
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
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "objects",
      lifetime.own(
        RenderProgram.create(
          name: "prog",
          context: cgl,
          vertexShader: solidColorVertexShader,
          fragmentShader: solidColorFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  phase.add(scene);

  {
    String name = "sphere";
    Material mat = lifetime.own(Material(name))
      ..setUniform(uColor, shapeToColor[name]!);
    Node node = MeshNode(
      name,
      lifetime.own(shapeIcosahedron(scene.program, subdivisions: 3)),
      mat,
    )..setPos(0.0, 0.0, 0.0);
    scene.add(node);
  }
  {
    String name = "cube";
    Material mat = lifetime.own(Material(name))
      ..setUniform(uColor, shapeToColor[name]!);
    Node node = MeshNode(name, lifetime.own(shapeCube(scene.program)), mat)
      ..setPos(-5.0, 0.0, -5.0);
    scene.add(node);
  }

  {
    String name = "cylinder";
    Material mat = lifetime.own(Material(name))
      ..setUniform(uColor, shapeToColor[name]!);
    Node node = MeshNode(
      name,
      lifetime.own(shapeCylinder(scene.program, 3.0, 6.0, 2.0, 32)),
      mat,
    )..setPos(5.0, 0.0, -5.0);
    scene.add(node);
  }
  {
    String name = "quad";
    Material mat = lifetime.own(Material(name))
      ..setUniform(uColor, shapeToColor[name]!);
    Node node = MeshNode(name, lifetime.own(shapeQuad(scene.program, 2)), mat)
      ..setPos(-5.0, 0.0, 5.0);
    scene.add(node);
  }
  {
    String name = "torus";
    Material mat = lifetime.own(Material(name))
      ..setUniform(uColor, shapeToColor[name]!);
    Node node = MeshNode(
      name,
      lifetime.own(shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4)),
      mat,
    )..setPos(5.0, 0.0, 5.0);
    scene.add(node);
  }

  final mouse = lifetime.own(Mouse.forTarget(canvas));
  final Uint8List pixelData = Uint8List(1 * 4);

  String getShapeUnderCusorInfo() {
    DateTime start = DateTime.now();
    final rect = canvas.getBoundingClientRect();
    final x = (mouse.currentX * canvas.width / rect.width).floor().clamp(
      0,
      canvas.width - 1,
    );
    final y =
        (canvas.height -
                1 -
                (mouse.currentY * canvas.height / rect.height).floor())
            .clamp(0, canvas.height - 1);
    cgl.readPixels(x, y, 1, 1, glRgba, glUnsignedByte, pixelData);
    vm.Vector3 pick = vm.Vector3(
      pixelData[0] + 0.0,
      pixelData[1] + 0.0,
      pixelData[2] + 0.0,
    )..scale(1.0 / 255.0);
    String shape = "NONE";
    for (String name in shapeToColor.keys) {
      if (shapeToColor[name] == pick) {
        shape = name;
        break;
      }
    }
    Duration dur = DateTime.now().difference(start);
    return "$shape<br>$x.$y<br>$pixelData<br>${dur.inMicroseconds}us";
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
    phase.viewPortW = viewport.viewportWidthPixels;
    phase.viewPortH = viewport.viewportHeightPixels;
    phase.draw();

    info.innerHTML = getShapeUnderCusorInfo().toJS;

    // this also clears keyboard data
    mouse.afterFrameCleanup();

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
