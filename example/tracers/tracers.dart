import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

final ShaderObject blurdVertexShader = ShaderObject("bluredV")
  ..addAttributeVars([aPosition])
  ..setBody([nullVertexShaderString]);

final ShaderObject bluredFragmentShader = ShaderObject("bluredF")
  ..addUniformVars([uColorAlpha])
  ..setBody([
    """
void main() {  
    $oFragColor = $uColorAlpha;
}
    """,
  ]);

Scene makeStarScene(ChronosGL cgl, UniformGroup perspective, int num) {
  Scene scene = Scene(
    "stars",
    RenderProgram(
      "stars",
      cgl,
      pointSpritesVertexShader,
      pointSpritesFragmentShader,
    ),
    [perspective],
  );
  scene.add(Utils.makeParticles(scene.program, num));
  return scene;
}

void main() {
  StatsFps fps = StatsFps(
    html.document.getElementById("stats")!,
    "blue",
    "gray",
  );

  html.CanvasElement canvas =
      html.document.querySelector('#webgl-canvas') as html.CanvasElement;
  ChronosGL cgl = ChronosGL(canvas, preserveDrawingBuffer: true);
  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);
  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );
  phase.clearDepthBuffer = true;
  phase.clearColorBuffer = false;

  Scene scene = Scene(
    "blur",
    RenderProgram("blur", cgl, blurdVertexShader, bluredFragmentShader),
    [perspective],
  );
  phase.add(scene);

  // Every frame 4% of the screen will be blurred
  Material matBlur = Material.transparent("blur", blendEquationStandard)
    ..setUniform(uColorAlpha, vm.Vector4(0.0, 0.0, 0.0, 0.04));
  scene.add(Node("", shapeQuad(scene.program, 1), matBlur));

  phase.add(makeStarScene(cgl, perspective, 2000));

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.005;
    orbit.animate(elapsed);

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
