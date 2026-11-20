import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

web.HTMLSelectElement gEffect =
    web.document.querySelector('#effect') as web.HTMLSelectElement;

class Effect {
  Effect(ChronosGL cgl, ShaderObject shader, this.uniforms)
    : name = uniforms.name,
      program = lifetime.own(
        RenderProgram(uniforms.name, cgl, effectVertexShader, shader),
      ) {
    all[uniforms.name] = this;
  }

  static Map<String, Effect> all = {};

  final String name;
  final RenderProgram program;
  final UniformGroup uniforms;
}

void registerEffects(ChronosGL cgl) {
  Effect(cgl, copyFragmentShader, UniformGroup("none"));

  Effect(cgl, toonFragmentShader, UniformGroup("toon"));

  Effect(
    cgl,
    hexPixelateFragmentShader,
    UniformGroup("hexalate-6")
      ..setUniform(uCenter2, vm.Vector2(0.5, 0.5))
      ..setUniform(uPointSize, 6.0),
  );

  Effect(
    cgl,
    dotFragmentShader,
    UniformGroup("dot")
      ..setUniform(uCenter2, vm.Vector2(0.0, 0.0))
      ..setUniform(uScale, 0.8)
      ..setUniform(uAngle, 0.5),
  );

  Effect(
    cgl,
    tvDistortionFragmentShader,
    UniformGroup("tv-distortion")
      ..setUniform(uScale, 0.0009)
      ..setUniform(uTime, 0.0),
  );

  Effect(
    cgl,
    lumidotsFragmentShader,
    UniformGroup("lumidots-4")..setUniform(uPointSize, 4.0),
  );

  Effect(
    cgl,
    squarePixelateFragmentShader,
    UniformGroup("square-4")..setUniform(uPointSize, 4.0),
  );

  Effect(
    cgl,
    scanlineFragmentShader,
    UniformGroup("scanline")..setUniform(uRange, vm.Vector2(120.0, 240.0)),
  );

  Effect(cgl, waterFragmentShader, UniformGroup("water"));

  Effect(cgl, crosshatchFragmentShader(0), UniformGroup("crosshatch"));

  Effect(
    cgl,
    sepiaFragmentShader,
    UniformGroup("sepia")..setUniform(uScale, 0.5),
  );

  Effect(cgl, techicolorFragmentShader, UniformGroup("technicolor"));

  Effect(
    cgl,
    vignettingFragmentShader,
    UniformGroup("vigenetting")..setUniform(uRange, vm.Vector2(0.4, 0.7)),
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
  // Make sure canvas has full screen resolution
  final width = canvas.clientWidth;
  final height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;

  final ChronosGL cgl = ChronosGL.fromCanvas(canvas);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: OrthographicCamera(
        left: -1,
        right: 1,
        bottom: -1,
        top: 1,
        near: -1,
        far: 1,
      ),
    ),
  );

  final ImageTexture texture = lifetime.own(
    ImageTexture.fromVideo(
      context: cgl,
      name: "video",
      video: video,
      properties: texturePropertiesVideo,
    ),
  );
  final Framebuffer screen = lifetime.own(Framebuffer.screen(cgl));
  final RenderProgram progScale = lifetime.own(
    RenderProgram(
      "bg",
      cgl,
      scalingCopyVertexShader,
      scalingCopyFragmentShader,
    ),
  );
  final Material material = lifetime.own(Material("mat"))
    ..setUniform(uTexture, texture);
  final GpuMesh unitQuad = lifetime.own(shapeQuad(progScale, 1));

  final Framebuffer fb0 = lifetime.own(
    Framebuffer.defaultFramebuffer(cgl, width, height),
  );
  final Framebuffer fb1 = lifetime.own(
    Framebuffer.defaultFramebuffer(cgl, width, height),
  );

  registerEffects(cgl);
  assert(
    Effect.all["dot"]!.program.hasDownwardCompatibleAttributesTo(progScale),
  );

  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    try {
      // Get new image from camera and update texture with it.
      texture.update();
    } catch (exception) {
      print(exception);
    }

    // scale
    fb0.activate(glClearAll, 0, 0, width, height);
    progScale.draw(unitQuad, [material]);

    int rounds = 1;
    for (int i = 0; i < rounds; ++i) {
      Framebuffer src = i % 2 == 0 ? fb0 : fb1;
      Framebuffer dst = i % 2 == 0 ? fb1 : fb0;

      if (i == rounds - 1) dst = screen;

      dst.activate(
        glClearAll,
        0,
        0,
        identical(dst, screen) ? canvas.width : width,
        identical(dst, screen) ? canvas.height : height,
      );
      // apply effect
      Effect active = Effect.all[gEffect.value]!;
      active.uniforms.forceUniform(uTime, timeMs / 1000.0);
      active.uniforms.forceUniform(uTexture, src.colorTexture!);
      active.program.draw(unitQuad, [active.uniforms]);
    }
    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs + 0.0);
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
