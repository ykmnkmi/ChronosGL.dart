import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

// This scene is responsible for filling the entire screen with a texture
// gleaned from the camera
RenderBatch backgroundScene(ChronosGL cgl, ImageTexture texture) {
  final RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "bg",
      lifetime.own(
        RenderProgram(
          "bg",
          cgl,
          scalingCopyVertexShader,
          scalingCopyFragmentShader,
        ),
      ),
      [],
    ),
  );

  final Material matBackground = lifetime.own(Material("bg"))
    ..forceUniform(cDepthWrite, false)
    ..setUniform(uTexture, texture);

  scene.add(
    MeshNode("bg", lifetime.own(shapeQuad(scene.program, 1)), matBackground),
  );
  return scene;
}

RenderBatch cubeScene(ChronosGL cgl, List<UniformGroup> uniforms) {
  // This scene renders the a red cube in front of the background
  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "objects",
      lifetime.own(
        RenderProgram(
          "solid",
          cgl,
          solidColorVertexShader,
          solidColorFragmentShader,
        ),
      ),
      uniforms,
    ),
  );

  final Material matCube = lifetime.own(Material("cube"))
    ..setUniform(uColor, colorRed.toVector3());

  double dim = 0.2;
  Node cube = MeshNode(
    "cube",
    lifetime.own(shapeCube(scene.program, x: dim, y: dim, z: dim)),
    matCube,
  )..setPos(-5.0, 0.0, -5.0);
  scene.add(cube);
  return scene;
}

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

  final ImageTexture texture = lifetime.own(
    ImageTexture.fromVideo(
      context: cgl,
      name: "video",
      video: video,
      properties: texturePropertiesVideo,
    ),
  );

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

  phase.add(backgroundScene(cgl, texture));
  final RenderBatch sceneCube = cubeScene(cgl, [perspective]);
  final Node cubeNode = sceneCube.nodes[0];
  phase.add(sceneCube);

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
    orbit.update(elapsed / 1000.0);
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

    fps.updateFrameCount(timeMs, out.join("<br>"));

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
