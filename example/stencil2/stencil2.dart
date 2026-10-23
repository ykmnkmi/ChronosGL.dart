import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

final ShaderObject stencilVertexShader = ShaderObject("stencilV")
  ..addAttributeVars([aPosition])
  ..setBody([nullVertexShaderString]);

final ShaderObject stencilFragmentShader = ShaderObject("stencilF")
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
final TheStencilFunction stencilAlways = TheStencilFunction(glAlways, 1, 0xff);

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

final TheStencilOp stencilWriteIfPixelSet = TheStencilOp(
  glKeep,
  glKeep,
  glReplace,
);

final TheStencilOp stencilWriteNever = TheStencilOp(glKeep, glKeep, glKeep);

void main() {
  StatsFps fps = StatsFps(
    web.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;
  ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final int width = canvas.clientWidth;
  final int height = canvas.clientHeight;
  canvas.width = width;
  canvas.height = height;
  perspective.adjustAspect(width, height);

  final RenderPhase phase = RenderPhase("main", cgl)
    ..viewPortW = width
    ..viewPortH = height;

  final Material matGenStencil = Material("stencil")
    ..setUniform(uTime, 1.0)
    ..setUniform(uCanvasSize, vm.Vector2(0.0 + width, 0.0 + height))
    ..forceUniform(cStencilFunc, stencilAlways)
    ..forceUniform(cStencilOp, stencilWriteIfPixelSet)
    ..forceUniform(cStencilWrite, 0xff) // only write stencil
    ..forceUniform(cDepthWrite, false)
    ..forceUniform(cColorWrite, [false, false, false, false])
    ..forceUniform(cDepthTest, false);
  {
    Scene scene = Scene(
      "stencil",
      RenderProgram("stencil", cgl, stencilVertexShader, stencilFragmentShader),
      [],
    );
    phase.add(scene);
    scene.add(Node("unit", shapeQuad(scene.program, 1), matGenStencil));
  }

  final Material matOnStencil = Material("onstencil")
    ..setUniform(uColor, colorRed)
    ..forceUniform(cStencilFunc, stencilNotEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0) // only write color/depth
    ..forceUniform(cDepthWrite, true)
    ..forceUniform(cColorWrite, [true, true, true, true])
    ..forceUniform(cDepthTest, true);

  final Material matOffStencil = Material("offstencil")
    ..setUniform(uColor, colorBlue)
    ..forceUniform(cStencilFunc, stencilEqualZero)
    ..forceUniform(cStencilOp, stencilWriteNever)
    ..forceUniform(cStencilWrite, 0x0) // only write color/depth
    ..forceUniform(cDepthWrite, true)
    ..forceUniform(cColorWrite, [true, true, true, true])
    ..forceUniform(cDepthTest, true);

  {
    Scene scene = Scene(
      "onstencil",
      RenderProgram(
        "onstencil",
        cgl,
        solidColorVertexShader,
        solidColorFragmentShader,
      ),
      [perspective],
    );
    phase.add(scene);
    scene.add(
      Node(
        "cylinder",
        shapeCylinder(scene.program, 2.0, 4.0, 4.0, 32),
        matOnStencil,
      )..setPos(10.0, 0.0, -10.0),
    );

    scene.add(
      Node(
        "torus",
        shapeTorusKnot(scene.program, radius: 2.5, tubeRadius: 0.8),
        matOnStencil,
      )..setPos(10.0, 0.0, 10.0),
    );

    scene.add(
      Node(
        "sphere",
        shapeIcosahedron(scene.program, subdivisions: 3, scale: 5.0),
        matOffStencil,
      )..setPos(0.0, 0.0, 0.0),
    );

    scene.add(
      Node(
        "cube",
        shapeCube(scene.program, x: 2.0, y: 2.0, z: 2.0),
        matOffStencil,
      )..setPos(-10.0, 0.0, -10.0),
    );
  }
  orbit.azimuth = 1.1;
  double lastTimeMs = 0.0;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
    orbit.animate(elapsed);

    //print ("@@ ${timeMs / 2000.0 % 1.0} ");
    matGenStencil.forceUniform(uTime, (math.sin(timeMs / 2000.0) + 1.0) * 0.25);

    List<DrawStats> stats = [];
    phase.draw(stats);
    List<String> out = [];
    for (DrawStats d in stats) {
      out.add(d.toString());
    }

    web.window.requestAnimationFrame(onFrame);
    fps.updateFrameCount(lastTimeMs, out.join("<br>"));
  }

  onFrame = animate.toJS;

  animate(0.0);
}
