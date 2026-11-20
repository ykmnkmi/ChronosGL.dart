import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../shared/particles.dart';

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../shared/lifetime.dart';

final lifetime = ExampleLifetime();

// A very simple shaders - many other are available out of the box.
// aPosition will be provided by the GpuMesh object `torus`
// uPerspectiveViewMatrix
// uPerspectiveViewMatrix will be provided by the Material object `materialBasic`
// uModelMatrix will be provided by the Material object `materialBasic`
final ShaderObject demoVertexShader = ShaderObject.vertex("demoVertexShader")
  ..addAttributeVars([aPosition])
  ..addVaryingVars([vColor])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..setBody([
    """
void main() {
    gl_Position = $uPerspectiveViewMatrix *
                  $uModelMatrix *
                  vec4($aPosition, 1.0);
    $vColor.r = sin($aPosition.x)/2.0+0.5;
    $vColor.g = cos($aPosition.y)/2.0+0.5;
    $vColor.b = sin($aPosition.z)/2.0+0.5;
}
""",
  ]);

final ShaderObject demoFragmentShader =
    ShaderObject.fragment("demoFragmentShader")
      ..addVaryingVars([vColor])
      ..setBody([
        """
void main() {
    $oFragColor.rgb = $vColor;
}
    """,
      ]);

void randomPointOnUnitSphere(vm.Vector3 out, math.Random rng) {
  while (true) {
    double x = rng.nextDouble() * 2.0 - 1.0;
    double y = rng.nextDouble() * 2.0 - 1.0;
    double sq = x * x + y * y;
    if (sq >= 1.0) continue;
    double rt = math.sqrt(1.0 - sq);
    out.setValues(2.0 * x * rt, 2.0 * y * rt, 1.0 - 2.0 * sq);
    return;
  }
}

class CameraShaker {
  CameraShaker(this._camera, this._rng);

  void shake(double amplitude) {
    unshake();
    randomPointOnUnitSphere(_offset, _rng);
    _offset.scale(amplitude);
    _camera.setPositionFromVector(_camera.worldPosition + _offset);
  }

  void unshake() {
    _offset.scale(-1.0);
    _camera.setPositionFromVector(_camera.worldPosition + _offset);
    _offset.setZero();
  }

  final vm.Vector3 _offset = vm.Vector3.zero();
  final math.Random _rng;
  final Camera _camera;
}

void main() {
  // The canvas is what we render the 3d scene into.
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;

  gLogLevel = 1; // enable more logging
  // Create a ChronosGL object for the canvas.
  final ChronosGL cgl = ChronosGL.fromCanvas(canvas);

  // Keep the mathematical camera separate from browser input.
  final camera = PerspectiveCamera(near: 0.1, far: 1000.0);
  canvas.tabIndex = 0;
  final orbit = lifetime.own(
    OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 5.0,
      azimuth: 0.0,
      polar: 0.0,
    ),
  );
  // CameraUniforms supplies the view, projection and world-space eye.
  // CanvasViewport synchronizes the backing pixels and camera aspect ratio.
  final CameraUniforms perspective = CameraUniforms(camera);
  final viewport = lifetime.own(
    CanvasViewport.forCanvas(cgl: cgl, canvas: canvas, camera: camera),
  );

  // Create the main shader program for displaying the torus.
  final RenderProgram prog = lifetime.own(
    RenderProgram.create(
      name: "basic",
      context: cgl,
      vertexShader: demoVertexShader,
      fragmentShader: demoFragmentShader,
    ),
  );

  // Create the Material, basically a container for uniforms, which provides
  // uModelMatrix and controls basic settings for depth buffers and blending.
  final Material material = lifetime.own(Material("torus-mat"))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  // Make a torus and add it to the first program providing the
  // aPosition attribute.
  final GpuMesh torus = lifetime.own(
    shapeTorusKnot(prog, radius: 1.0, tubeRadius: 0.4),
  );

  // Create the second shader program and the point sprites. The details are
  // hidden in the library functions.
  final RenderProgram progSprites = lifetime.own(
    RenderProgram.create(
      name: "basic",
      context: cgl,
      vertexShader: pointSpritesVertexShader,
      fragmentShader: pointSpritesFragmentShader,
    ),
  );
  final Material materialStars = lifetime.own(makeStarMaterial(cgl))
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final GpuMesh stars = lifetime.own(
    makeStarMesh(progSprites, 2000, 100.0, random: math.Random()),
  );

  final math.Random rng = math.Random(0);
  final CameraShaker shaker = CameraShaker(camera, rng);
  // Main loop body
  double lastShakeMs = 0.0;
  double lastTimeMs = 0.0;
  bool firstFrame = true;
  const double shakeIntervalMs = 2000.0;
  const double shakeDurationMs = 500.0;

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
    // animate the camera a little
    orbit.azimuth += 0.18 * elapsed / 1000;
    // allow the camera to also reflect mouse movement.
    shaker.unshake();
    orbit.update(elapsed / 1000);

    final double shakeAgeMs = lastTimeMs - (lastShakeMs + shakeIntervalMs);

    if (shakeAgeMs >= 0.0) {
      if (shakeAgeMs >= shakeDurationMs) {
        shaker.unshake();
        lastShakeMs = lastTimeMs;
      }

      shaker.shake((500 - shakeAgeMs) * 0.0001);
    }

    // use default framebuffer which also auto clears itself
    prog.draw(torus, [perspective, material]);
    progSprites.draw(stars, [perspective, materialStars]);

    lifetime.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  lifetime.requestAnimationFrame(onFrame);
}
