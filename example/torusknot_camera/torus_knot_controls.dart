import 'package:chronosgl/camera.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Example-owned motion through a torus knot, independent of camera projection.
///
/// [positionAt] samples the same curve as the example's tunnel geometry. It
/// receives the curve parameter in radians and writes into caller-owned storage.
/// The camera and sampler remain owned by their callers.
class TorusKnotControls {
  TorusKnotControls(this.camera, {required this.positionAt}) {
    update(0);
  }

  final Camera camera;
  final void Function(double parameter, vm.Vector3 out) positionAt;
  final vm.Vector3 _position = vm.Vector3.zero();
  final vm.Vector3 _ahead = vm.Vector3.zero();
  double _elapsedSeconds = 0;

  /// Advances the curve by one radian every three seconds.
  ///
  /// The radial up direction preserves the tunnel's original rolling motion.
  /// Negative and nonfinite steps are rejected before changing the camera.
  void update(double deltaSeconds) {
    final nextSeconds = _elapsedSeconds + deltaSeconds;
    if (!deltaSeconds.isFinite || deltaSeconds < 0 || !nextSeconds.isFinite) {
      throw ArgumentError.value(
        deltaSeconds,
        'deltaSeconds',
        'Must be finite and nonnegative',
      );
    }
    final parameter = nextSeconds / 3;
    positionAt(parameter, _position);
    positionAt(parameter + 0.01, _ahead);
    camera.setPositionFromVector(_position);
    camera.lookAt(_ahead, upHint: _position);
    _elapsedSeconds = nextSeconds;
  }
}
