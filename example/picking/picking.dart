import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

Map<String, vm.Vector3> shapeToColor = {
  "sphere": colorCyan,
  "cube": colorRed,
  "cylinder": colorGreen,
  "quad": colorMagenta,
  "torus": colorBlue,
};

void main() {
  final web.HTMLDivElement info =
      web.document.querySelector('#info') as web.HTMLDivElement;

  final StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);

  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final RenderPhase phase = RenderPhase("main", cgl);
  final Scene scene = Scene(
    "objects",
    RenderProgram(
      "prog",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    [perspective],
  );
  phase.add(scene);

  {
    String name = "sphere";
    Material mat = Material(name)..setUniform(uColor, shapeToColor[name]!);
    Node node = Node(
      name,
      shapeIcosahedron(scene.program, subdivisions: 3),
      mat,
    )..setPos(0.0, 0.0, 0.0);
    scene.add(node);
  }
  {
    String name = "cube";
    Material mat = Material(name)..setUniform(uColor, shapeToColor[name]!);
    Node node = Node(name, shapeCube(scene.program), mat)
      ..setPos(-5.0, 0.0, -5.0);
    scene.add(node);
  }

  {
    String name = "cylinder";
    Material mat = Material(name)..setUniform(uColor, shapeToColor[name]!);
    Node node = Node(name, shapeCylinder(scene.program, 3.0, 6.0, 2.0, 32), mat)
      ..setPos(5.0, 0.0, -5.0);
    scene.add(node);
  }
  {
    String name = "quad";
    Material mat = Material(name)..setUniform(uColor, shapeToColor[name]!);
    Node node = Node(name, shapeQuad(scene.program, 2), mat)
      ..setPos(-5.0, 0.0, 5.0);
    scene.add(node);
  }
  {
    String name = "torus";
    Material mat = Material(name)..setUniform(uColor, shapeToColor[name]!);
    Node node = Node(
      name,
      shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4),
      mat,
    )..setPos(5.0, 0.0, 5.0);
    scene.add(node);
  }

  void resolutionChange(web.Event? ev) {
    int w = canvas.clientWidth;
    int h = canvas.clientHeight;
    canvas.width = w;
    canvas.height = h;
    print("size change $w $h");
    perspective.adjustAspect(w, h);
    phase.viewPortW = w;
    phase.viewPortH = h;
  }

  resolutionChange(null);
  web.EventStreamProviders.resizeEvent
      .forTarget(web.window)
      .listen(resolutionChange);

  final Uint8List pixelData = Uint8List(1 * 4);

  String getShapeUnderCusorInfo() {
    DateTime start = DateTime.now();
    int x = orbit.mouse.currentX;
    int y = canvas.clientHeight - orbit.mouse.currentY;
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
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;

    orbit.azimuth += 0.001;

    phase.draw();

    info.innerHTML = getShapeUnderCusorInfo().toJS;

    // this also clears keyboard data
    orbit.animate(elapsed);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
