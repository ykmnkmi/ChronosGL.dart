import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';

// This scene is responsible for filling the entire screen with a texture
// gleaned from the camera
Scene backgroundScene(ChronosGL cgl, ImageTexture texture) {
  final Scene scene = Scene(
    "bg",
    RenderProgram(
      "bg",
      cgl,
      scalingCopyVertexShader,
      scalingCopyFragmentShader,
    ),
    [],
  );

  final Material matBackground = Material("bg")
    ..forceUniform(cDepthWrite, false)
    ..setUniform(uTexture, texture);

  scene.add(Node("bg", shapeQuad(scene.program, 1), matBackground));
  return scene;
}

Scene cubeScene(ChronosGL cgl, List<UniformGroup> uniforms) {
  // This scene renders the a red cube in front of the background
  Scene scene = Scene(
    "objects",
    RenderProgram(
      "solid",
      cgl,
      solidColorVertexShader,
      solidColorFragmentShader,
    ),
    uniforms,
  );

  final Material matCube = Material("cube")..setUniform(uColor, colorRed);

  double dim = 0.2;
  Node cube = Node(
    "cube",
    shapeCube(scene.program, x: dim, y: dim, z: dim),
    matCube,
  )..setPos(-5.0, 0.0, -5.0);
  scene.add(cube);
  return scene;
}

void main2(web.HTMLVideoElement? video) {
  if (video == null) {
    web.window.alert(
      "Could not access camera - do you have a camera installed?",
    );
    return;
  }
  final StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;

  final ChronosGL cgl = ChronosGL(canvas);
  final OrbitCamera orbit = OrbitCamera(15.0, 10.0, 0.0, canvas);
  final Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final ImageTexture texture = ImageTexture(
    cgl,
    "video",
    video,
    texturePropertiesVideo,
  );

  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );

  phase.add(backgroundScene(cgl, texture));
  final Scene sceneCube = cubeScene(cgl, [perspective]);
  final Node cubeNode = sceneCube.nodes[0];
  phase.add(sceneCube);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.animate(elapsed);
    cubeNode.rotX(0.01);
    cubeNode.rotY(0.01);
    try {
      // Get new image from camera and update texture with it.
      texture.update();
    } catch (exception) {
      print(exception);
    }
    List<DrawStats> stats = [];
    phase.draw(stats);
    List<String> out = [];
    for (DrawStats d in stats) {
      out.add(d.toString());
    }

    fps.updateFrameCount(lastTimeMs, out.join("<br>"));

    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  animate(0.0);
}

void main() {
  makeVideoElementFromCamera().then(main2).catchError((Object error) {
    web.window.alert("Camera error $error: - do you have a camera installed?");
  });
}
