import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:async';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

const String modelFile = "../ct_logo.obj";

web.HTMLSelectElement gEffect =
    web.document.querySelector('#effect') as web.HTMLSelectElement;

web.HTMLSelectElement gScene =
    web.document.querySelector('#scene') as web.HTMLSelectElement;

double rangeOverTime(double a, double b, double interval, double t) {
  //double s = t % interval * 2.0 * math.PI;
  return (b - a) * (0.5 + 0.5 * math.cos(t)) + a;
}

class Effect {
  Effect(ChronosGL cgl, ShaderObject shader, this.uniforms)
    : name = uniforms.name,
      program = RenderProgram(uniforms.name, cgl, effectVertexShader, shader) {
    all[uniforms.name] = this;
  }

  static Map<String, Effect> all = {};

  final String name;
  final RenderProgram program;
  final UniformGroup uniforms;
}

void registerEffects(ChronosGL cgl, Texture fb) {
  Effect(
    cgl,
    copyFragmentShader,
    UniformGroup("none")..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    toonFragmentShader,
    UniformGroup("toon")..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    hexPixelateFragmentShader,
    UniformGroup("hexalate-10")
      ..setUniform(uCenter2, vm.Vector2(0.5, 0.5))
      ..setUniform(uPointSize, 10.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    hexPixelateFragmentShader,
    UniformGroup("hexalate-20")
      ..setUniform(uCenter2, vm.Vector2(0.5, 0.5))
      ..setUniform(uPointSize, 20.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    hexPixelateFragmentShader,
    UniformGroup("hexalate-varying")
      ..setUniform(uCenter2, vm.Vector2(0.5, 0.5))
      ..setUniform(uPointSize, 10.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    dotFragmentShader,
    UniformGroup("dot")
      ..setUniform(uCenter2, vm.Vector2(0.0, 0.0))
      ..setUniform(uScale, 0.8)
      ..setUniform(uAngle, 0.5)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    dotFragmentShader,
    UniformGroup("dot2")
      ..setUniform(uCenter2, vm.Vector2(0.0, 0.0))
      ..setUniform(uScale, 0.3)
      ..setUniform(uAngle, 0.5)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    tvDistortionFragmentShader,
    UniformGroup("tv-distortion")
      ..setUniform(uScale, 0.0009)
      ..setUniform(uTime, 0.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    kaleidoscopeShader,
    UniformGroup("kaleidoscope8")
      ..setUniform(uScale, 8.0)
      ..setUniform(uCenter2, vm.Vector2(0.5, 0.5))
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    kaleidoscopeShader,
    UniformGroup("kaleidoscope5")
      ..setUniform(uScale, 5.0)
      ..setUniform(uCenter2, vm.Vector2(0.5, 0.5))
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    lumidotsFragmentShader,
    UniformGroup("lumidots-8")
      ..setUniform(uPointSize, 8.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    lumidotsFragmentShader,
    UniformGroup("lumidots-16")
      ..setUniform(uPointSize, 16.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    lumidotsFragmentShader,
    UniformGroup("lumidots-varying")
      ..setUniform(uPointSize, 16.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    squarePixelateFragmentShader,
    UniformGroup("square-8")
      ..setUniform(uPointSize, 8.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    squarePixelateFragmentShader,
    UniformGroup("square-16")
      ..setUniform(uPointSize, 16.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    squarePixelateFragmentShader,
    UniformGroup("square-varying")
      ..setUniform(uPointSize, 16.0)
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    scanlineFragmentShader,
    UniformGroup("scanline")
      ..setUniform(uRange, vm.Vector2(120.0, 240.0))
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    waterFragmentShader,
    UniformGroup("water")..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    crosshatchFragmentShader(0),
    UniformGroup("crosshatch")..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    luminosityHighPassFragmentShader,
    UniformGroup("luminosity-highpass")
      ..setUniform(uRange, vm.Vector2(0.85, 0.86))
      ..setUniform(uColorAlpha, vm.Vector4.zero())
      ..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    fisheyeFragmentShader,
    UniformGroup("fisheye")..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    filmFragmentShader,
    UniformGroup("film")..setUniform(uTexture, fb),
  );

  Effect(
    cgl,
    convolution3x3FragmentShader,
    UniformGroup("emboss")
      ..setUniform(uConvolutionMatrix, convolutionMatrixEmboss)
      ..setUniform(uColor, convolutionOffsetEmboss),
  );

  Effect(
    cgl,
    convolution3x3FragmentShader,
    UniformGroup("emboss2")
      ..setUniform(uConvolutionMatrix, convolutionMatrixEmboss2)
      ..setUniform(uColor, convolutionOffsetEmboss2),
  );
  Effect(
    cgl,
    convolution3x3FragmentShader,
    UniformGroup("engrave")
      ..setUniform(uConvolutionMatrix, convolutionMatrixEngrave)
      ..setUniform(uColor, convolutionOffsetEngrave),
  );

  Effect(
    cgl,
    convolution3x3FragmentShader,
    UniformGroup("sharpen")
      ..setUniform(uConvolutionMatrix, convolutionMatrixSharpen)
      ..setUniform(uColor, convolutionOffsetSharpen),
  );

  Effect(
    cgl,
    convolution3x3FragmentShader,
    UniformGroup("edges")
      ..setUniform(uConvolutionMatrix, convolutionMatrixEdges)
      ..setUniform(uColor, convolutionOffsetEdges),
  );

  Effect(
    cgl,
    convolution3x3FragmentShader,
    UniformGroup("blur")
      ..setUniform(uConvolutionMatrix, convolutionMatrixBlur)
      ..setUniform(uColor, convolutionOffsetBlur),
  );

  for (String o in Effect.all.keys) {
    gEffect.appendChild(web.HTMLOptionElement()..textContent = o);
  }
}

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  final width = canvas.clientWidth;
  final height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;

  final ChronosGL cgl = ChronosGL(canvas);

  final OrbitCamera orbit = OrbitCamera(15.0, -45.0, 0.3, canvas);
  final Perspective perspective = Perspective(orbit, 0.1, 2520.0)
    ..adjustAspect(width, height);

  final Framebuffer screen = Framebuffer.screen(cgl);

  final Framebuffer fb = Framebuffer.defaultFramebuffer(cgl, width, height);

  registerEffects(cgl, fb.colorTexture!);

  final RenderProgram progDemo = RenderProgram(
    "demo",
    cgl,
    demoVertexShader,
    demoFragmentShader,
  );

  MeshData unitQuad = shapeQuad(Effect.all["dot"]!.program, 1);
  late MeshData ctLogo;

  Material material = Material("mat")
    ..setUniform(uColor, colorGray8)
    ..setUniform(uModelMatrix, vm.Matrix4.identity()..rotateX(math.pi / 2));

  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.01;
    orbit.animate(elapsed);

    Effect active = Effect.all[gEffect.value]!;
    final double timeSec = timeMs / 1000.0;

    if (gEffect.value == "tv-distortion") {
      active.uniforms.forceUniform(uTime, timeSec);
    } else if (gEffect.value == "hexalate-varying") {
      active.uniforms.forceUniform(
        uPointSize,
        rangeOverTime(4.0, 30.0, 20.0, timeSec),
      );
    } else if (gEffect.value == "square-varying") {
      active.uniforms.forceUniform(
        uPointSize,
        rangeOverTime(4.0, 30.0, 20.0, timeSec),
      );
    } else if (gEffect.value == "lumidots-varying") {
      active.uniforms.forceUniform(
        uPointSize,
        rangeOverTime(4.0, 30.0, 20.0, timeSec),
      );
    } else if (gEffect.value == "water") {
      active.uniforms.forceUniform(uTime, lastTimeMs / 1000.0);
    }

    // Draw logo to fb
    fb.activate(glClearAll, 0, 0, width, height);
    progDemo.draw(ctLogo, [perspective, material]);

    // Apply currently active effect/program to fb and show result on screen
    screen.activate(glClearAll, 0, 0, width, height);
    active.program.draw(unitQuad, [active.uniforms]);

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs);
  }

  onFrame = animate.toJS;

  List<Future<Object>> futures = [loadRaw(modelFile)];

  Future.wait(futures).then((list) {
    // Setup Mesh
    GeometryBuilder gb = importGeometryFromWavefront(list[0] as String);
    ctLogo = geometryBuilderToMeshData("", progDemo, gb);
    animate(0.0);
  });
}
