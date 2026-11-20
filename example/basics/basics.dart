import 'dart:math' as math;

import 'dart:js_interop';
import "dart:async";

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

RenderBatch makeStarScene(ChronosGL cgl, UniformGroup perspective, int num) {
  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "stars",
      lifetime.own(
        RenderProgram(
          "stars",
          cgl,
          pointSpritesVertexShader,
          pointSpritesFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  scene.add(makeParticles(scene.program, num, random: math.Random()));
  return scene;
}

final List<Future<Object>> gLoadables = [];

RenderBatch makeMainScene(ChronosGL cgl, List<UniformGroup> uniforms) {
  final RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "objects",
      lifetime.own(
        RenderProgram(
          "textured",
          cgl,
          texturedVertexShader,
          texturedFragmentShader,
        ),
      ),
      uniforms,
    ),
  );
  // textures will be set after they are loaded
  final Material matWood = lifetime.own(Material("wood"))
    ..setUniform(uColor, colorBlack.toVector3());
  var f3 = loadImage("../wood.jpg")
    ..then((img) {
      if (lifetime.isDisposed) return;
      Texture wood = lifetime.own(
        ImageTexture.fromImage(context: cgl, name: "../wood.jpg", image: img),
      );
      matWood.setUniform(uTexture, wood);
    });
  gLoadables.add(f3);

  final Material matGradient = lifetime.own(Material("gradient"))
    ..setUniform(uColor, colorRed.toVector3());
  var f1 = loadImage("../gradient.jpg")
    ..then((img) {
      if (lifetime.isDisposed) return;
      Texture gradient = lifetime.own(
        ImageTexture.fromImage(
          context: cgl,
          name: "../gradient.jpg",
          image: img,
        ),
      );
      matGradient.setUniform(uTexture, gradient);
    });
  gLoadables.add(f1);

  final Material matTrans = lifetime.own(Material("trans"))
    ..setUniform(uColor, colorGray4.toVector3())
    ..forceUniform(cBlendEquation, blendEquationStandard);
  var f2 = loadImage("../transparent.png")
    ..then((img) {
      if (lifetime.isDisposed) return;
      Texture trans = lifetime.own(
        ImageTexture.fromImage(
          context: cgl,
          name: "../transparent.png",
          image: img,
        ),
      );
      matTrans.setUniform(uTexture, trans);
    });
  gLoadables.add(f2);

  {
    Node ico = MeshNode(
      "sphere",
      lifetime.own(shapeIcosahedron(scene.program, subdivisions: 3)),
      matWood,
    )..setPos(0.0, 0.0, 0.0);
    scene.add(ico);
  }
  {
    Node cube = MeshNode(
      "cube",
      lifetime.own(shapeCube(scene.program)),
      matGradient,
    )..setPos(-5.0, 0.0, -5.0);
    scene.add(cube);
  }

  {
    Node cyl = MeshNode(
      "cylinder",
      lifetime.own(shapeCylinder(scene.program, 3.0, 6.0, 2.0, 32)),
      matTrans,
    )..setPos(5.0, 0.0, -5.0);
    scene.add(cyl);
  }
  {
    Node quad = MeshNode(
      "quad",
      lifetime.own(shapeQuad(scene.program, 2)),
      matTrans,
    )..setPos(-5.0, 0.0, 5.0);
    scene.add(quad);
  }
  {
    Node torus = MeshNode(
      "torus",
      lifetime.own(shapeTorusKnot(scene.program, radius: 1.0, tubeRadius: 0.4)),
      matGradient,
    )..setPos(5.0, 0.0, 5.0);
    scene.add(torus);
  }

  return scene;
}

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
  canvas.tabIndex = 0;
  canvas.focus();
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 25.0,
      azimuth: 10.0,
      polar: 0.0,
    ),
  );
  final perspective = CameraUniforms(camera);

  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );

  phase.add(makeMainScene(cgl, [perspective]));
  phase.add(makeStarScene(cgl, perspective, 2000));

  double? lastTimeMs;
  late final JSFunction onFrame;
  void animate(double timeMs) {
    if (lifetime.isDisposed) return;
    if (!viewport.update()) {
      lastTimeMs = timeMs;
      lifetime.requestAnimationFrame(onFrame);
      return;
    }
    final elapsed = lastTimeMs == null ? 0.0 : timeMs - lastTimeMs!;
    lastTimeMs = timeMs + 0.0;
    orbit.azimuth += 0.06 * elapsed / 1000.0;
    orbit.update(elapsed / 1000.0);

    List<DrawStats> stats = [];
    phase.draw(stats);
    List<String> out = [];
    for (DrawStats d in stats) {
      out.add(d.toString());
    }

    lifetime.requestAnimationFrame(onFrame);
    fps.updateFrameCount(timeMs, out.join("<br>"));
  }

  onFrame = animate.toJS;

  Future.wait(gLoadables).then((list) {
    if (lifetime.isDisposed) return;
    lifetime.requestAnimationFrame(onFrame);
  });
}
