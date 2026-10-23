import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:vector_math/vector_math.dart' as vm;

// A very simple shaders - many other are available out of the box.
// aPosition will be provided by the MeshData object `torus`
// uPerspectiveViewMatrix
// uPerspectiveViewMatrix will be provided by the Material object `materialBasic`
// uModelMatrix will be provided by the Material object `materialBasic`
final ShaderObject demoVertexShader = ShaderObject("demoVertexShader")
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

final ShaderObject demoFragmentShader = ShaderObject("demoFragmentShader")
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
    _camera.addPosFromVec(_offset);
  }

  void unshake() {
    _offset.scale(-1.0);
    _camera.addPosFromVec(_offset);
    _offset.setZero();
  }

  final vm.Vector3 _offset = vm.Vector3.zero();
  final math.Random _rng;
  final Spatial _camera;
}

void main() {
  // The canvas is what we render the 3d scene into.
  final web.HTMLCanvasElement canvas =
      web.document.querySelector('#webgl-canvas') as web.HTMLCanvasElement;

  gLogLevel = 1; // enable more logging
  // Create a ChronosGL object for the canvas.
  final ChronosGL cgl = ChronosGL(canvas);

  // Create interactive camera, listening to 'body' element for
  // control inputs like mouse drag events.
  final OrbitCamera orbit = OrbitCamera(5.0, 0.0, 0.0, web.document.body!);
  // Create a perspective. We use a combined view+perspective matrix,
  // which is obtained by combining te view matrix from the camera with
  // the perspective matrix.
  // The perspective also make sure canvas has full screen resolution
  // and that we respond to resize events.
  final PerspectiveResizeAware perspective = PerspectiveResizeAware(
    cgl,
    canvas,
    orbit,
    0.1,
    1000.0,
  );

  // Create the main shader program for displaying the torus.
  final RenderProgram prog = RenderProgram(
    "basic",
    cgl,
    demoVertexShader,
    demoFragmentShader,
  );

  // Create the Material, basically a container for uniforms, which provides
  // uModelMatrix and controls basic settings for depth buffers and blending.
  final Material material = Material("torus-mat")
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  // Make a torus and add it to the first program providing the
  // aPosition attribute.
  final MeshData torus = shapeTorusKnot(prog, radius: 1.0, tubeRadius: 0.4);

  // Create the second shader program and the point sprites. The details are
  // hidden in the library functions.
  final RenderProgram progSprites = RenderProgram(
    "basic",
    cgl,
    pointSpritesVertexShader,
    pointSpritesFragmentShader,
  );
  final Material materialStars = Utils.makeStarMaterial(cgl)
    ..setUniform(uModelMatrix, vm.Matrix4.identity());
  final MeshData stars = Utils.makeStarMesh(progSprites, 2000, 100.0);

  final math.Random rng = math.Random(0);
  final CameraShaker shaker = CameraShaker(orbit, rng);
  // Main loop body
  double lastShakeMs = 0.0;
  double lastTimeMs = 0.0;
  const double shakeIntervalMs = 2000.0;
  const double shakeDurationMs = 500.0;

  late final JSFunction onFrame;
  void animate(double timeMs) {
    double elapsed = timeMs - lastTimeMs;
    lastTimeMs = timeMs + 0.0;
    // animate the camera a little
    orbit.azimuth += 0.003;
    // allow the camera to also reflect mouse movement.
    orbit.animate(elapsed);

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

    web.window.requestAnimationFrame(onFrame);
  }

  onFrame = animate.toJS;

  animate(0.0);
}
