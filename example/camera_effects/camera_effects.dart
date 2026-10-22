import 'dart:html' as html;

import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/chronosgl.dart';
import 'package:web/web.dart' as web;

html.SelectElement gEffect =
    html.document.querySelector('#effect') as html.SelectElement;

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
    gEffect.appendHtml("<option>$o</option>");
  }
}

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
  // Make sure canvas has full screen resolution
  final width = canvas.clientWidth;
  final height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;

  final ChronosGL cgl = ChronosGL(canvas);

  final ImageTexture texture = ImageTexture(
    cgl,
    "video",
    video,
    texturePropertiesVideo,
  );
  final Framebuffer screen = Framebuffer.screen(cgl);
  final RenderProgram progScale = RenderProgram(
    "bg",
    cgl,
    scalingCopyVertexShader,
    scalingCopyFragmentShader,
  );
  final Material material = Material("mat")..setUniform(uTexture, texture);
  final MeshData unitQuad = shapeQuad(progScale, 1);

  final Framebuffer fb0 = Framebuffer.defaultFramebuffer(cgl, width, height);
  final Framebuffer fb1 = Framebuffer.defaultFramebuffer(cgl, width, height);

  registerEffects(cgl);
  assert(
    Effect.all["dot"]!.program.hasDownwardCompatibleAttributesTo(progScale),
  );

  void animate(num timeMs) {
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

      dst.activate(glClearAll, 0, 0, width, height);
      // apply effect
      Effect active = Effect.all[gEffect.value]!;
      active.uniforms.forceUniform(uTime, timeMs / 1000.0);
      active.uniforms.forceUniform(uTexture, src.colorTexture!);
      active.program.draw(unitQuad, [active.uniforms]);
    }
    html.window.animationFrame.then(animate);
    fps.updateFrameCount(timeMs + 0.0);
  }

  animate(0.0);
}

void main() {
  makeVideoElementFromCamera().then(main2).catchError((Object error) {
    html.window.alert("Camera error $error: - do you have a camera installed?");
  });
}
