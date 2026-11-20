import 'dart:math' as math;

import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'package:vector_math/vector_math.dart' as vm;

import "dart:async";

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
  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 15.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram progCube = lifetime.own(
    RenderProgram("solid", cgl, cubeMapVertexShader, cubeMapFragmentShader),
  );

  // The Skybox and the cube use the same material
  final Material mat = lifetime.own(Material("cubemap"))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final GpuMesh mdCube = lifetime.own(
    shapeCube(progCube, x: 2.0, y: 2.0, z: 2.0),
  );
  final GpuMesh mdSky = lifetime.own(
    shapeCube(progCube, x: 512.0, y: 512.0, z: 512.0),
  );

  final RenderProgram progStars = lifetime.own(
    RenderProgram(
      "stars",
      cgl,
      pointSpritesVertexShader,
      pointSpritesFragmentShader,
    ),
  );
  final Material matStars = lifetime.own(makeStarMaterial(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final GpuMesh mdStars = lifetime.own(
    makeStarMesh(progStars, 2000, 100.0, random: math.Random()),
  );

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
    progCube.draw(mdCube, [mat, perspective]);
    progCube.draw(mdSky, [mat, perspective]);
    progStars.draw(mdStars, [matStars, perspective]);

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs);
  }

  onFrame = animate.toJS;

  List<Future<Object>> futures = loadCubeImages("skybox_", ".png");

  Future.wait(futures).then((list) {
    if (lifetime.isDisposed) return;
    Texture cubeTex = lifetime.own(
      CubeTexture.fromImages(
        context: cgl,
        name: "stars",
        images: list.cast<web.HTMLImageElement>(),
      ),
    );
    mat.setUniform(uCubeTexture, cubeTex);
    lifetime.requestAnimationFrame(onFrame);
  });
}
