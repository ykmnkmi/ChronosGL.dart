@TestOn('chrome')
library;

import 'package:chronosgl/src/core/lib.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

// Characterization of the known bug, not the desired camera contract.
// In phase 3 (3.6), replace the incorrect-position expectations with the
// preserved world position. See docs/1.5_CAMERA_POSITION_REPRODUCTION.md.
void main() {
  test('Known bug: lookAt replaces the camera world position', () {
    final camera = Spatial('camera')..setPos(0, 0, 10);
    // getPos returns reusable scratch storage, so retain a copy.
    final before = vm.Vector3.copy(camera.getPos());
    expect(before.storage, orderedEquals([0, 0, 10]));

    camera.lookAt(vm.Vector3.zero());

    expect(camera.getPos().storage, orderedEquals([0, 0, -10]));
    expect(camera.getEyePosition().storage, orderedEquals([0, 0, -10]));

    // The view matrix itself is valid: the world-space eye maps to the origin.
    final view = vm.Matrix4.zero();
    camera.getViewMatrix(view);
    expect(view.transformed3(before).storage, orderedEquals([0, 0, 0]));
  });

  test('Known bug: Perspective publishes view translation as uEyePosition', () {
    final camera = Spatial('camera')..setPos(0, 0, 10);
    camera.lookAt(vm.Vector3.zero());
    final perspective = Perspective(camera, 0.1, 100);

    final uniforms = perspective.getUniforms();
    final eye = uniforms[uEyePosition] as vm.Vector3;

    // Desired world-space value: [0, 0, 10]. No WebGL context is needed
    // to reproduce the incorrect value supplied to the rendering pipeline.
    expect(eye.storage, orderedEquals([0, 0, -10]));
  });
}
