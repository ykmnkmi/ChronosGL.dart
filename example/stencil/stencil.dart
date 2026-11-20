import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final web.HTMLInputElement gStencil =
    web.document.querySelector('#stencil') as web.HTMLInputElement;

final ShaderObject stencilVertexShader = ShaderObject.vertex("stencilV")
  ..addAttributeVars([aPosition, aTexUV])
  ..addVaryingVars([vTexUV])
  ..setBody([nullVertexShaderWithTextureForwardString]);

final ShaderObject stencilFragmentShader = ShaderObject.fragment("stencilF")
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

  return lifetime.own(
    TypedTextureMutable.allocate(
      context: cgl,
      name: "frame::depth.stencil",
      width: width,
      height: height,
      internalFormat: glRgba,
      properties: texturePropertiesFramebuffer,
      format: glRgba,
      dataType: glUnsignedByte,
      data: data,
    ),
  );
}

const TheStencilFunction stencilEqualZero = TheStencilFunction(
  glEqual,
  0,
  0xff,
);

const TheStencilFunction stencilNotEqualZero = TheStencilFunction(
  glNotequal,
  0,
  0xff,
);

const TheStencilFunction stencilAlways = TheStencilFunction(glAlways, 1, 0xff);

const TheStencilOp stencilWriteNever = TheStencilOp(glKeep, glKeep, glKeep);

const TheStencilOp stencilWriteIfPixelSet = TheStencilOp(
  glKeep,
  glKeep,
  glReplace,
);

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
  ChronosGL cgl = ChronosGL.fromCanvas(
    canvas,
    faceCulling: true,
    preserveDrawingBuffer: true,
  );
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );
  CameraUniforms perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  var width = viewport.drawingBufferWidthPixels;
  var height = viewport.drawingBufferHeightPixels;
  canvas.width = width;
  canvas.height = height;

  // Initialize Stencil Buffer
  // Not we do not suppress writes to color/depth buffers which is
  // nice for debugging. These buffers will be cleared when we write
  // scene. Obviously, we preserve the stencil buffer.

  TypedTextureMutable stencilBuffer = makeStripedStencilBuffer(
    cgl,
    width,
    height,
    8,
  );

  final Material matGenStencil = lifetime.own(Material("stencil"))
    ..setUniform(uTexture, stencilBuffer)
    ..forceUniform(cStencilFunc, stencilAlways)
    ..forceUniform(cStencilOp, stencilWriteIfPixelSet)
    ..forceUniform(cStencilWrite, 0xff); // only write stencil

  final RenderProgram stencilWriter = lifetime.own(
    RenderProgram.create(
      name: "stencil",
      context: cgl,
      vertexShader: stencilVertexShader,
      fragmentShader: stencilFragmentShader,
    ),
  );

  final stencilQuad = lifetime.own(shapeQuad(stencilWriter, 1));

  RenderPass phase = lifetime.ownPass(RenderPass("main", cgl))
    ..viewPortW = width
    ..viewPortH = height
    ..clearStencilBuffer = false;

  final Material matRed = lifetime.own(Material("red"))
    ..setUniform(uColor, colorRed.toVector3())
    ..forceUniform(cStencilFunc, stencilNotEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0);

  final Material matBlue = lifetime.own(Material("blue"))
    ..setUniform(uColor, colorBlue.toVector3())
    ..forceUniform(cStencilFunc, stencilEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0);

  {
    RenderBatch scene = lifetime.ownBatch(
      RenderBatch(
        "solid",
        lifetime.own(
          RenderProgram.create(
            name: "solid",
            context: cgl,
            vertexShader: solidColorVertexShader,
            fragmentShader: solidColorFragmentShader,
          ),
        ),
        [perspective],
      ),
    );
    phase.add(scene);

    scene.add(
      MeshNode(
        "sphere",
        lifetime.own(shapeIcosahedron(scene.program, subdivisions: 3)),
        matRed,
      )..setPos(0.0, 0.0, 0.0),
    );

    scene.add(
      MeshNode("cube", lifetime.own(shapeCube(scene.program)), matBlue)
        ..setPos(-5.0, 0.0, -5.0),
    );

    scene.add(
      MeshNode(
        "cylinder",
        lifetime.own(shapeCylinder(scene.program, 1.0, 3.0, 2.0, 32)),
        matRed,
      )..setPos(5.0, 0.0, -5.0),
    );

    scene.add(
      MeshNode(
        "torus",
        lifetime.own(
          shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4),
        ),
        matBlue,
      )..setPos(5.0, 0.0, 5.0),
    );
  }

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
    if (width != viewport.drawingBufferWidthPixels ||
        height != viewport.drawingBufferHeightPixels) {
      width = viewport.drawingBufferWidthPixels;
      height = viewport.drawingBufferHeightPixels;
      stencilBuffer.dispose();
      stencilBuffer = makeStripedStencilBuffer(cgl, width, height, 8);
      matGenStencil.forceUniform(uTexture, stencilBuffer);
    }
    cgl.viewport(0, 0, width, height);
    cgl.depthMask(true);
    cgl.stencilMask(0xff);
    cgl.clear(glDepthBufferBit | glStencilBufferBit);
    stencilWriter.draw(stencilQuad, [matGenStencil]);
    final elapsed = firstFrame ? 0.0 : timeMs - lastTimeMs;
    firstFrame = false;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000;
    orbit.update(elapsed / 1000);
    phase.viewPortW = viewport.viewportWidthPixels;
    phase.viewPortH = viewport.viewportHeightPixels;

    matBlue.forceUniform(
      cStencilFunc,
      gStencil.checked ? stencilEqualZero : stencilFunctionNone,
    );

    matRed.forceUniform(
      cStencilFunc,
      gStencil.checked ? stencilNotEqualZero : stencilFunctionNone,
    );

    List<DrawStats> stats = [];
    phase.draw(stats);
    List<String> out = [];
    for (DrawStats d in stats) {
      out.add(d.toString());
    }

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs, out.join("<br>"));
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
