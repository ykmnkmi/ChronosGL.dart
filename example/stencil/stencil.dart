import 'dart:html' as html;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';

final html.InputElement gStencil =
    html.document.querySelector('#stencil') as html.InputElement;

final ShaderObject stencilVertexShader = ShaderObject("stencilV")
  ..addAttributeVars([aPosition, aTexUV])
  ..addVaryingVars([vTexUV])
  ..setBody([nullVertexShaderWithTextureForwardString]);

final ShaderObject stencilFragmentShader = ShaderObject("stencilF")
  ..addUniformVars([uTexture])
  ..addVaryingVars([vTexUV])
  ..setBody([
    """
void main() {
   vec4 p = texture($uTexture, $vTexUV);
   if (p.r > 0.0 || p.g >  0.0 || p.b > 0.0) {
      // It does not really matter what we write.
      // Any write will set the stencil buffer to 1
      $oFragColor = vec4(1.0, 1.0, 0.0, 1.0);
   } else {
      // do not set color and hence do not change stencil buffer
      discard;
   }
}
""",
  ]);

TypedTextureMutable makeStripedStencilBuffer(
  ChronosGL cgl,
  int width,
  int height,
  int stripeWidth,
) {
  Uint8List data = Uint8List(width * height * 4);
  for (int y = 0; y < height; ++y) {
    for (int x = 0; x < width; ++x) {
      int mask = x % (2 * stripeWidth) < stripeWidth ? 0 : 0xff;
      int offset = 4 * (y * width + x);
      data[offset + 0] = mask;
      data[offset + 1] = mask;
      data[offset + 2] = mask;
      data[offset + 3] = mask;
    }
  }

  return TypedTextureMutable(
    cgl,
    "frame::depth.stencil",
    width,
    height,
    glRgba,
    texturePropertiesFramebuffer,
    glRgba,
    glUnsignedByte,
    data,
  );
}

final TheStencilFunction stencilEqualZero = TheStencilFunction(
  glEqual,
  0,
  0xff,
);

final TheStencilFunction stencilNotEqualZero = TheStencilFunction(
  glNotequal,
  0,
  0xff,
);

final TheStencilFunction stencilAlways = TheStencilFunction(glAlways, 1, 0xff);

final TheStencilOp stencilWriteNever = TheStencilOp(glKeep, glKeep, glKeep);

final TheStencilOp stencilWriteIfPixelSet = TheStencilOp(
  glKeep,
  glKeep,
  glReplace,
);

void main() {
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  ChronosGL cgl = ChronosGL(
    canvas,
    faceCulling: true,
    preserveDrawingBuffer: true,
  );
  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final int width = canvas.clientWidth;
  final int height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;
  perspective.adjustAspect(width, height);

  // Initialize Stencil Buffer
  // Not we do not suppress writes to color/depth buffers which is
  // nice for debugging. These buffers will be cleared when we write
  // scene. Obviously, we preserve the stencil buffer.

  final TypedTextureMutable stencilBuffer = makeStripedStencilBuffer(
    cgl,
    width,
    height,
    8,
  );

  final Material matGenStencil = Material("stencil")
    ..setUniform(uTexture, stencilBuffer)
    ..forceUniform(cStencilFunc, stencilAlways)
    ..forceUniform(cStencilOp, stencilWriteIfPixelSet)
    ..forceUniform(cStencilWrite, 0xff); // only write stencil

  final RenderProgram stencilWriter = RenderProgram(
    "stencil",
    cgl,
    stencilVertexShader,
    stencilFragmentShader,
  );

  cgl.viewport(0, 0, width, height);
  stencilWriter.draw(shapeQuad(stencilWriter, 1), [matGenStencil]);

  RenderPhase phase = RenderPhase("main", cgl)
    ..viewPortW = width
    ..viewPortH = height
    ..clearStencilBuffer = false;

  final Material matRed = Material("red")
    ..setUniform(uColor, colorRed)
    ..forceUniform(cStencilFunc, stencilNotEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0);

  final Material matBlue = Material("blue")
    ..setUniform(uColor, colorBlue)
    ..forceUniform(cStencilFunc, stencilEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0);

  {
    Scene scene = Scene(
      "solid",
      RenderProgram(
        "solid",
        cgl,
        solidColorVertexShader,
        solidColorFragmentShader,
      ),
      [perspective],
    );
    phase.add(scene);

    scene.add(
      Node("sphere", shapeIcosahedron(scene.program, subdivisions: 3), matRed)
        ..setPos(0.0, 0.0, 0.0),
    );

    scene.add(
      Node("cube", shapeCube(scene.program), matBlue)..setPos(-5.0, 0.0, -5.0),
    );

    scene.add(
      Node("cylinder", shapeCylinder(scene.program, 1.0, 3.0, 2.0, 32), matRed)
        ..setPos(5.0, 0.0, -5.0),
    );

    scene.add(
      Node(
        "torus",
        shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4),
        matBlue,
      )..setPos(5.0, 0.0, 5.0),
    );
  }

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    matBlue.forceUniform(
      cStencilFunc,
      gStencil.checked! ? stencilEqualZero : stencilFunctionNone,
    );

    matRed.forceUniform(
      cStencilFunc,
      gStencil.checked! ? stencilNotEqualZero : stencilFunctionNone,
    );

    List<DrawStats> stats = [];
    phase.draw(stats);
    List<String> out = [];
    for (DrawStats d in stats) {
      out.add(d.toString());
    }

    html.window.animationFrame.then(animate);
    fps.updateFrameCount(lastTimeMs, out.join("<br>"));
  }

  animate(0.0);
}
