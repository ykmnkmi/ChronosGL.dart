import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:web/web.dart' as web;

import "dart:async";

final List<Future<Object>> gLoadables = [];

void main() {
  final StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;

  final ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  final OrbitCamera orbit = OrbitCamera(165.0, 0.0, 0.0, canvas);
  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  final RenderProgram programTexture = RenderProgram(
    "textured",
    cgl,
    texturedVertexShader,
    texturedFragmentShader,
  );
  final RenderProgram programPerlin = RenderProgram(
    "perlin",
    cgl,
    perlinNoiseVertexShader,
    makePerlinNoiseColorFragmentShader(false),
  );

  final MeshData torus = shapeTorusKnot(programTexture);

  // A gradient texture will be added after it has loaded.
  final Material matTexture = Material("texture")
    ..setUniform(
      uModelMatrix,
      vm.Matrix4.identity()..setTranslationRaw(-50.0, 0.0, 0.0),
    )
    ..setUniform(uColor, vm.Vector3.zero());
  var future = loadImage("../gradient.jpg")
    ..then((img) {
      Texture gradient = ImageTexture(cgl, "../gradient.jpg", img);
      matTexture.setUniform(uTexture, gradient);
    });
  gLoadables.add(future);

  final Material matPerlin = Material("perlin")
    ..setUniform(uTransformationMatrix, vm.Matrix4.zero())
    ..setUniform(
      uModelMatrix,
      vm.Matrix4.identity()..setTranslationRaw(50.0, 0.0, 0.0),
    );

  final RenderProgram progStars = RenderProgram(
    "stars",
    cgl,
    pointSpritesVertexShader,
    pointSpritesFragmentShader,
  );
  final Material matStars = Utils.makeStarMaterial(cgl)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final MeshData mdStars = Utils.makeStarMesh(progStars, 2000, 200.0);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);
    matPerlin.forceUniform(uTime, timeMs / 1000.0);
    programTexture.draw(torus, [perspective, matTexture]);
    programPerlin.draw(torus, [perspective, matPerlin]);
    progStars.draw(mdStars, [matStars, perspective]);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
