import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

void main2(web.HTMLVideoElement? video) {
  if (video == null) {
    html.window.alert(
      "Could not access camera - do you have a camera installed?",
    );
    return;
  }
  final StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  final html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
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
  void animate(num timeMs) {
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

    html.window.animationFrame.then(animate);
  }

  animate(0.0);
}

void main() {
  makeVideoElementFromCamera().then(main2).catchError((Object error) {
    html.window.alert("Camera error $error: - do you have a camera installed?");
  });
}
