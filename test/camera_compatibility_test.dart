@TestOn('chrome')
library;

import 'package:chronosgl/camera.dart' as cameras;
import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  test('public camera and aggregate imports expose the same types', () {
    final Camera perspective = cameras.PerspectiveCamera(near: 1, far: 100);
    final cameras.Camera orthographic = OrthographicCamera(
      left: -1,
      right: 1,
      bottom: -1,
      top: 1,
      near: 0,
      far: 100,
    );
    expect(perspective, isA<PerspectiveCamera>());
    expect(orthographic, isA<cameras.OrthographicCamera>());
    for (final camera in <Camera>[perspective, orthographic]) {
      camera.setPosition(0, 0, 10);
      camera.lookAt(vm.Vector3.zero());
      expect(camera.worldPosition.storage, orderedEquals([0, 0, 10]));
    }
  });
}
