import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final ShaderObject stencilVertexShader = ShaderObject.vertex("stencilV")
  ..addAttributeVars([aPosition])
  ..setBody([nullVertexShaderString]);

final ShaderObject stencilFragmentShader = ShaderObject.fragment("stencilF")
  ..addUniformVars([uTime, uCanvasSize])
  ..setBody([
    """
void main() {
   float radius = $uTime * max($uCanvasSize.x, $uCanvasSize.y);
   vec2 center = vec2($uCanvasSize.x, $uCanvasSize.y) * 0.5;
   if (distance(center, gl_FragCoord.xy) > radius) {
      // It does not really matter what we write.
      // Any write will set the stencil buffer to 1
      $oFragColor = vec4(1.0);
   } else {
      // do not set color and hence do not change stencil buffer
      discard;
   }
}
""",
  ]);
const TheStencilFunction stencilAlways = TheStencilFunction(glAlways, 1, 0xff);

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

const TheStencilOp stencilWriteIfPixelSet = TheStencilOp(
  glKeep,
  glKeep,
  glReplace,
);

const TheStencilOp stencilWriteNever = TheStencilOp(glKeep, glKeep, glKeep);

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
  ChronosGL cgl = ChronosGL.fromCanvas(canvas, faceCulling: true);
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

  final int width = viewport.drawingBufferWidthPixels;
  final int height = viewport.drawingBufferHeightPixels;
  canvas.width = width;
  canvas.height = height;

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl))
    ..viewPortW = width
    ..viewPortH = height;

  final Material matGenStencil = lifetime.own(Material("stencil"))
    ..setUniform(uTime, 1.0)
    ..setUniform(uCanvasSize, vm.Vector2(0.0 + width, 0.0 + height))
    ..forceUniform(cStencilFunc, stencilAlways)
    ..forceUniform(cStencilOp, stencilWriteIfPixelSet)
    ..forceUniform(cStencilWrite, 0xff) // only write stencil
    ..forceUniform(cDepthWrite, false)
    ..forceUniform(cColorWrite, [false, false, false, false])
    ..forceUniform(cDepthTest, false);
  {
    RenderBatch scene = lifetime.ownBatch(
      RenderBatch(
        "stencil",
        lifetime.own(
          RenderProgram.create(
            name: "stencil",
            context: cgl,
            vertexShader: stencilVertexShader,
            fragmentShader: stencilFragmentShader,
          ),
        ),
        [],
      ),
    );
    phase.add(scene);
    scene.add(
      MeshNode(
        "unit",
        lifetime.own(shapeQuad(scene.program, 1)),
        matGenStencil,
      ),
    );
  }

  final Material matOnStencil = lifetime.own(Material("onstencil"))
    ..setUniform(uColor, colorRed.toVector3())
    ..forceUniform(cStencilFunc, stencilNotEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0) // only write color/depth
    ..forceUniform(cDepthWrite, true)
    ..forceUniform(cColorWrite, [true, true, true, true])
    ..forceUniform(cDepthTest, true);

  final Material matOffStencil = lifetime.own(Material("offstencil"))
    ..setUniform(uColor, colorBlue.toVector3())
    ..forceUniform(cStencilFunc, stencilEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0) // only write color/depth
    ..forceUniform(cDepthWrite, true)
    ..forceUniform(cColorWrite, [true, true, true, true])
    ..forceUniform(cDepthTest, true);

  {
    RenderBatch scene = lifetime.ownBatch(
      RenderBatch(
        "onstencil",
        lifetime.own(
          RenderProgram.create(
            name: "onstencil",
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
        "cylinder",
        lifetime.own(shapeCylinder(scene.program, 2.0, 4.0, 4.0, 32)),
        matOnStencil,
      )..setPos(10.0, 0.0, -10.0),
    );

    scene.add(
      MeshNode(
        "torus",
        lifetime.own(
          shapeTorusKnot(scene.program, radius: 2.5, tubeRadius: 0.8),
        ),
        matOnStencil,
      )..setPos(10.0, 0.0, 10.0),
    );

    scene.add(
      MeshNode(
        "sphere",
        lifetime.own(
          shapeIcosahedron(scene.program, subdivisions: 3, scale: 5.0),
        ),
        matOffStencil,
      )..setPos(0.0, 0.0, 0.0),
    );

    scene.add(
      MeshNode(
        "cube",
        lifetime.own(shapeCube(scene.program, x: 2.0, y: 2.0, z: 2.0)),
        matOffStencil,
      )..setPos(-10.0, 0.0, -10.0),
    );
  }
  orbit.azimuth = 1.1;
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
    phase.viewPortW = viewport.viewportWidthPixels;
    phase.viewPortH = viewport.viewportHeightPixels;

    //print ("@@ ${timeMs / 2000.0 % 1.0} ");
    matGenStencil.forceUniform(
      uCanvasSize,
      vm.Vector2(
        viewport.viewportWidthPixels.toDouble(),
        viewport.viewportHeightPixels.toDouble(),
      ),
    );
    matGenStencil.forceUniform(uTime, (math.sin(timeMs / 2000.0) + 1.0) * 0.25);

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
