import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';

import 'package:web/web.dart' as web;

import 'package:vector_math/vector_math.dart' as vm;

import "dart:async";

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL(canvas);
  OrbitCamera orbit = OrbitCamera(15.0, 0.0, 0.0, canvas);
  PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  final RenderProgram progCube = RenderProgram(
    "solid",
    cgl,
    cubeMapVertexShader,
    cubeMapFragmentShader,
  );

  // The Skybox and the cube use the same material
  final Material mat = Material("cubemap")
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final MeshData mdCube = shapeCube(progCube, x: 2.0, y: 2.0, z: 2.0);
  final MeshData mdSky = shapeCube(progCube, x: 512.0, y: 512.0, z: 512.0);

  final RenderProgram progStars = RenderProgram(
    "stars",
    cgl,
    pointSpritesVertexShader,
    pointSpritesFragmentShader,
  );
  final Material matStars = Utils.makeStarMaterial(cgl)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final MeshData mdStars = Utils.makeStarMesh(progStars, 2000, 100.0);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    progCube.draw(mdCube, [mat, perspective]);
    progCube.draw(mdSky, [mat, perspective]);
    progStars.draw(mdStars, [matStars, perspective]);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  List<Future<Object>> futures = loadCubeImages("skybox_", ".png");

  Future.wait(futures).then((list) {
    Texture cubeTex = CubeTexture(cgl, "stars", list);
    mat.setUniform(uCubeTexture, cubeTex);
    animate(0.0);
  });
}
