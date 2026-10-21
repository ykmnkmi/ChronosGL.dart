import "dart:async";
import 'dart:html' as html;

import 'package:chronosgl/chronosgl.dart';

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

final List<Future<Object>> gLoadables = [];

Scene makeMainScene(ChronosGL cgl, List<UniformGroup> uniforms) {
  final Scene scene = Scene(
    "objects",
    RenderProgram(
      "textured",
      cgl,
      texturedVertexShader,
      texturedFragmentShader,
    ),
    uniforms,
  );
  // textures will be set after they are loaded
  final Material matWood = Material("wood")..setUniform(uColor, colorBlack);
  var f3 = loadImage("../wood.jpg")
    ..then((html.ImageElement img) {
      Texture wood = ImageTexture(cgl, "../wood.jpg", img);
      matWood.setUniform(uTexture, wood);
    });
  gLoadables.add(f3);

  final Material matGradient = Material("gradient")
    ..setUniform(uColor, colorRed);
  var f1 = loadImage("../gradient.jpg")
    ..then((html.ImageElement img) {
      Texture gradient = ImageTexture(cgl, "../gradient.jpg", img);
      matGradient.setUniform(uTexture, gradient);
    });
  gLoadables.add(f1);

  final Material matTrans = Material("trans")
    ..setUniform(uColor, colorGray4)
    ..forceUniform(cBlendEquation, blendEquationStandard);
  var f2 = loadImage("../transparent.png")
    ..then((html.ImageElement img) {
      Texture trans = ImageTexture(cgl, "../transparent.png", img);
      matTrans.setUniform(uTexture, trans);
    });
  gLoadables.add(f2);

  {
    Node ico = Node(
      "sphere",
      shapeIcosahedron(scene.program, subdivisions: 3),
      matWood,
    )..setPos(0.0, 0.0, 0.0);
    scene.add(ico);
  }
  {
    Node cube = Node("cube", shapeCube(scene.program), matGradient)
      ..setPos(-5.0, 0.0, -5.0);
    scene.add(cube);
  }

  {
    Node cyl = Node(
      "cylinder",
      shapeCylinder(scene.program, 3.0, 6.0, 2.0, 32),
      matTrans,
    )..setPos(5.0, 0.0, -5.0);
    scene.add(cyl);
  }
  {
    Node quad = Node("quad", shapeQuad(scene.program, 2), matTrans)
      ..setPos(-5.0, 0.0, 5.0);
    scene.add(quad);
  }
  {
    Node torus = Node(
      "torus",
      shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4),
      matGradient,
    )..setPos(5.0, 0.0, 5.0);
    scene.add(torus);
  }

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
  ChronosGL cgl = ChronosGL(canvas, faceCulling: true);
  OrbitCamera orbit = OrbitCamera(25.0, 10.0, 0.0, canvas);
  Perspective perspective = Perspective(orbit, 0.1, 1000.0);

  final RenderPhaseResizeAware phase = RenderPhaseResizeAware(
    "main",
    cgl,
    canvas,
    perspective,
  );

  phase.add(makeMainScene(cgl, [perspective]));
  phase.add(makeStarScene(cgl, perspective, 2000));

  double lastTimeMs = 0.0;
  void animate(num timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.001;
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

  Future.wait(gLoadables).then((list) {
    animate(0.0);
  });
}
