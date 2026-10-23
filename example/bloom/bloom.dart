import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

final web.HTMLInputElement gLuminance =
    web.document.querySelector('#luminance') as web.HTMLInputElement;
final web.HTMLInputElement gIntensity =
    web.document.querySelector('#intensity') as web.HTMLInputElement;

class BloomEffect {
  BloomEffect(
    ChronosGL cgl,
    this.w,
    this.h,
    this.radius,
    int scale,
    this.fbIn,
    this.fbOut,
  ) : wSmall = w ~/ scale,
      hSmall = h ~/ scale,
      fb1 = Framebuffer.defaultFramebuffer(cgl, w ~/ scale, h ~/ scale),
      fb2 = Framebuffer.defaultFramebuffer(cgl, w ~/ scale, h ~/ scale) {
    progHighPass = RenderProgram(
      "highpass",
      cgl,
      uvPassthruVertexShader,
      scaledLuminosityHighPassFragmentShader,
    );

    progBloom = RenderProgram(
      "bloom",
      cgl,
      uvPassthruVertexShader,
      createBloomTextureFragmentShader(radius, radius * 1.0),
    );

    progApplyBloom = RenderProgram(
      "bloom",
      cgl,
      uvPassthruVertexShader,
      applyBloomEffectFragmentShader,
    );

    assert(
      progHighPass.hasDownwardCompatibleAttributesTo(progApplyBloom),
      "highpass incompatible attributes",
    );
    assert(
      progApplyBloom.hasCompatibleAttributesTo(progBloom),
      "bloom incompatible attributes",
    );
    unitQuad = shapeQuad(progApplyBloom, 1);

    // Note: the input uTexture varies between the various UniformGroups
    uniformsHighPass = UniformGroup("uniformsHighPass")
      ..setUniform(uRange, vm.Vector2(0.65, 0.65 + 0.01))
      ..setUniform(uColorAlpha, vm.Vector4.zero())
      ..setUniform(uTexture, fbIn.colorTexture!);

    uniformsBloomH = UniformGroup("Bloom Horizontal")
      ..setUniform(uDirection, vm.Vector2(1.5, 0.0))
      ..setUniform(uTexture, fb2.colorTexture!);

    uniformsBloomV = UniformGroup("Bloom Vertical")
      ..setUniform(uDirection, vm.Vector2(0.0, 1.5))
      ..setUniform(uTexture, fb1.colorTexture!);

    uniformsApply = UniformGroup("uniformApply")
      ..setUniform(uTexture, fbIn.colorTexture!)
      ..setUniform(uScale, 0.6)
      ..setUniform(uColor, colorWhite)
      ..setUniform(uTexture2, fb2.colorTexture!);
  }

  final int radius;
  final int w;
  final int h;
  final int wSmall;
  final int hSmall;
  final Framebuffer fbIn, fb1, fb2, fbOut;

  late RenderProgram progHighPass, progBloom, progApplyBloom;
  late UniformGroup uniformsHighPass,
      uniformsBloomH,
      uniformsBloomV,
      uniformsApply;
  late MeshData unitQuad;

  void draw(double luminosity, double intensity) {
    // Copy high intensity areas from fb to fb2
    fb2.activate(glClearAll, 0, 0, wSmall, hSmall);
    uniformsHighPass.forceUniform(
      uRange,
      vm.Vector2(luminosity, luminosity + 0.01),
    );
    progHighPass.draw(unitQuad, [uniformsHighPass]);

    // Blur fb2 to fb1 horizontally
    fb1.activate(glClearAll, 0, 0, wSmall, hSmall);
    progBloom.draw(unitQuad, [uniformsBloomH]);

    // Blur fb1 to fb2 vertically
    fb2.activate(glClearAll, 0, 0, wSmall, hSmall);
    progBloom.draw(unitQuad, [uniformsBloomV]);

    // Put all together: combine un-bloomed fb with fb2 and show result on screen
    fbOut.activate(glClearAll, 0, 0, w, h);
    uniformsApply.forceUniform(uScale, intensity);
    progApplyBloom.draw(unitQuad, [uniformsApply]);
  }
}

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );
  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  OrbitCamera orbit = OrbitCamera(165.0, 0.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final width = canvas.clientWidth;
  final height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;
  perspective.adjustAspect(width, height);

  final Framebuffer screen = Framebuffer.screen(cgl);
  final Framebuffer fb = Framebuffer.defaultFramebuffer(cgl, width, height);

  final RenderProgram progPerlinNoise = RenderProgram(
    "perlin",
    cgl,
    perlinNoiseVertexShader,
    makePerlinNoiseColorFragmentShader(true),
  );

  final Material material = Material("mat")
    ..setUniform(uTransformationMatrix, vm.Matrix4.identity())
    ..setUniform(uModelMatrix, vm.Matrix4.identity());

  final MeshData torus = shapeTorusKnot(progPerlinNoise);

  final BloomEffect bloom = BloomEffect(cgl, width, height, 6, 4, fb, screen);

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.01;
    orbit.animate(elapsed);
    material.forceUniform(uTime, timeMs / 1000.0);

    // Draw un-bloomed object to fb
    fb.activate(glClearAll, 0, 0, width, height);
    progPerlinNoise.draw(torus, [perspective, material]);
    bloom.draw(gLuminance.valueAsNumber * 1.0, gIntensity.valueAsNumber * 1.0);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
