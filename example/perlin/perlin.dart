import 'dart:math' as math;

import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import "dart:async";

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final List<Future<Object>> gLoadables = [];

void main() {
  final FpsPanel fps = lifetime.own(
    FpsPanel.attach(
      root: web.document.getElementById("stats")! as web.HTMLElement,
      foreground: "blue",
      background: "gray",
    ),
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;

  final ChronosGL cgl = ChronosGL.fromCanvas(canvas, faceCulling: true);
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 165.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  final CameraUniforms perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  final RenderProgram programTexture = lifetime.own(
    RenderProgram.create(
      name: "textured",
      context: cgl,
      vertexShader: texturedVertexShader,
      fragmentShader: texturedFragmentShader,
    ),
  );
  final RenderProgram programPerlin = lifetime.own(
    RenderProgram.create(
      name: "perlin",
      context: cgl,
      vertexShader: perlinNoiseVertexShader,
      fragmentShader: makePerlinNoiseColorFragmentShader(false),
    ),
  );

  final GpuMesh torus = lifetime.own(shapeTorusKnot(programTexture));

  // A gradient texture will be added after it has loaded.
  final Material matTexture = lifetime.own(Material("texture"))
    ..setUniform(
      uModelMatrix,
      vm.Matrix4.identity()..setTranslationRaw(-50.0, 0.0, 0.0),
    )
    ..setUniform(uColor, vm.Vector3.zero());
  var future = loadImage("../gradient.jpg")
    ..then((img) {
      if (lifetime.isDisposed) return;
      Texture gradient = lifetime.own(
        ImageTexture.fromImage(
          context: cgl,
          name: "../gradient.jpg",
          image: img,
        ),
      );
      matTexture.setUniform(uTexture, gradient);
    });
  gLoadables.add(future);

  final Material matPerlin = lifetime.own(Material("perlin"))
    ..setUniform(uTransformationMatrix, vm.Matrix4.zero())
    ..setUniform(
      uModelMatrix,
      vm.Matrix4.identity()..setTranslationRaw(50.0, 0.0, 0.0),
    );

  final RenderProgram progStars = lifetime.own(
    RenderProgram.create(
      name: "stars",
      context: cgl,
      vertexShader: pointSpritesVertexShader,
      fragmentShader: pointSpritesFragmentShader,
    ),
  );
  final Material matStars = lifetime.own(makeStarMaterial(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final GpuMesh mdStars = lifetime.own(
    makeStarMesh(progStars, 2000, 200.0, random: math.Random()),
  );

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
    matPerlin.forceUniform(uTime, timeMs / 1000.0);
    programTexture.draw(torus, [perspective, matTexture]);
    programPerlin.draw(torus, [perspective, matPerlin]);
    progStars.draw(mdStars, [matStars, perspective]);

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    if (lifetime.isDisposed) return;
    lifetime.requestAnimationFrame(onFrame);
  });
}
