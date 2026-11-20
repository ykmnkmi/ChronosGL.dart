import 'dart:math' as math;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

final ShaderObject blurdVertexShader = ShaderObject.vertex("bluredV")
  ..addAttributeVars([aPosition])
  ..setBody([nullVertexShaderString]);

final ShaderObject bluredFragmentShader = ShaderObject.fragment("bluredF")
  ..addUniformVars([uColorAlpha])
  ..setBody([
    """
void main() {  
    $oFragColor = $uColorAlpha;
}
    """,
  ]);

RenderBatch makeStarScene(ChronosGL cgl, UniformGroup perspective, int num) {
  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "stars",
      lifetime.own(
        RenderProgram.create(
          name: "stars",
          context: cgl,
          vertexShader: pointSpritesVertexShader,
          fragmentShader: pointSpritesFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  scene.add(makeParticles(scene.program, num, random: math.Random()));
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
  ChronosGL cgl = ChronosGL.fromCanvas(canvas, preserveDrawingBuffer: true);
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
  final RenderPass phase = lifetime.ownPass(RenderPass("main", cgl));
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
    ),
  );
  phase.clearDepthBuffer = true;
  phase.clearColorBuffer = false;

  RenderBatch scene = lifetime.ownBatch(
    RenderBatch(
      "blur",
      lifetime.own(
        RenderProgram.create(
          name: "blur",
          context: cgl,
          vertexShader: blurdVertexShader,
          fragmentShader: bluredFragmentShader,
        ),
      ),
      [perspective],
    ),
  );
  phase.add(scene);

  // Every frame 4% of the screen will be blurred
  Material matBlur = lifetime.own(
    Material.transparent("blur", blendEquationStandard),
  )..setUniform(uColorAlpha, vm.Vector4(0.0, 0.0, 0.0, 0.04));
  scene.add(MeshNode("", lifetime.own(shapeQuad(scene.program, 1)), matBlur));

  phase.add(makeStarScene(cgl, perspective, 2000));

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
    orbit.azimuth += 0.3 * elapsed / 1000;
    orbit.update(elapsed / 1000);

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
