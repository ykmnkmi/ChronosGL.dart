import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

void releaseVideo(web.HTMLVideoElement video) {
  video.pause();
  final source = video.srcObject;
  if (source != null && source.isA<web.MediaStream>()) {
    for (final track in (source as web.MediaStream).getTracks().toDart) {
      track.stop();
    }
  }
  video.srcObject = null;
  video.remove();
}

void main2(web.HTMLVideoElement? video) {
  if (lifetime.isDisposed) {
    if (video != null) releaseVideo(video);
    return;
  }
  if (video == null) {
    web.window.alert(
      "Could not access camera - do you have a camera installed?",
    );
    return;
  }
  lifetime.onDispose(() => releaseVideo(video));
  final FpsPanel fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );

  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final ChronosGL cgl = ChronosGL.fromCanvas(canvas);
  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 15.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram program = lifetime.own(
    RenderProgram("solid", cgl, texturedVertexShader, texturedFragmentShader),
  );

  GpuMesh cube = lifetime.own(shapeCube(program));

  final ImageTexture texture = lifetime.own(
    ImageTexture.fromVideo(
      context: cgl,
      name: "video",
      video: video,
      properties: texturePropertiesVideo,
    ),
  );

  final Material mat = lifetime.own(Material("cube"))
    ..setUniform(uColor, colorBlack.toVector3())
    ..setUniform(uModelMatrix, vm.Matrix4.identity())
    ..setUniform(uTexture, texture);

  double? lastTimeMs;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      lastTimeMs = timeMs;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = lastTimeMs == null ? 0.0 : timeMs - lastTimeMs!;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000.0;
    orbit.update(elapsed / 1000.0);
    try {
      // Get new image from camera and update texture with it.
      texture.update();
    } catch (exception) {
      print(exception);
    }
    program.draw(cube, [perspective, mat]);

    fps.updateFrameCount(timeMs);

    lifetime.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}

void main() {
  makeVideoElementFromCamera().then(main2).catchError((Object error) {
    if (!lifetime.isDisposed) {
      web.window.alert(
        "Camera error $error: - do you have a camera installed?",
      );
    }
  });
}
