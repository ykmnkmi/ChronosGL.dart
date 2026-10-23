import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

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
  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  final RenderProgram program = RenderProgram(
    "solid",
    cgl,
    texturedVertexShader,
    texturedFragmentShader,
  );

  MeshData cube = shapeCube(program);

  final ImageTexture texture = ImageTexture(
    cgl,
    "video",
    video,
    texturePropertiesVideo,
  );

  final Material mat = Material("cube")
    ..setUniform(uColor, colorBlack)
    ..setUniform(uModelMatrix, vm.Matrix4.identity())
    ..setUniform(uTexture, texture);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    try {
      // Get new image from camera and update texture with it.
      texture.update();
    } catch (exception) {
      print(exception);
    }
    program.draw(cube, [perspective, mat]);

    fps.updateFrameCount(lastTimeMs);

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
