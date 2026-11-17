import 'package:chronosgl/camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((v) => closeTo(v, 2e-5))),
  );
}

void main() {
  for (final orthographic in [false, true]) {
    final name = orthographic ? 'orthographic' : 'perspective';
    Camera create() => orthographic
        ? OrthographicCamera(
            left: -10,
            right: 10,
            bottom: -10,
            top: 10,
            near: 0.1,
            far: 100,
          )
        : PerspectiveCamera(near: 0.1, far: 100);

    test(
      '$name repeated lookAt preserves position and matches reference view',
      () {
        final camera = create()..setPosition(3, -4, 12);
        final eye = camera.worldPosition;
        final up = vm.Vector3(0.2, 1, 0.3);
        final originalUp = vm.Vector3.copy(up);
        for (final target in [
          vm.Vector3.zero(),
          vm.Vector3(-5, 7, 2),
          vm.Vector3(10, 1, 14),
          vm.Vector3.zero(),
        ]) {
          final originalTarget = vm.Vector3.copy(target);
          for (var repeat = 0; repeat < 3; repeat++) {
            camera.lookAt(target, upHint: up);
            expect(camera.worldPosition.storage, orderedEquals(eye.storage));
            expect(
              camera.worldMatrix.getTranslation().storage,
              orderedEquals(eye.storage),
            );
            final expectedView = vm.makeViewMatrix(eye, target, up);
            expectMatrix(camera.viewMatrix, expectedView);
            expectMatrix(
              camera.viewProjectionMatrix,
              camera.projectionMatrix..multiply(expectedView),
            );
            expect(camera.viewMatrix.transformed3(eye).length, lessThan(2e-5));
            expect(target.storage, orderedEquals(originalTarget.storage));
            expect(up.storage, orderedEquals(originalUp.storage));
          }
        }
      },
    );

    test('$name lookAt after moving uses the new world position', () {
      final camera = create()..setPosition(0, 0, 10);
      camera.lookAt(vm.Vector3.zero());
      final orientation = camera.worldRotation;
      camera.setPosition(-7, 2, 5);
      expect(camera.worldRotation.storage, orderedEquals(orientation.storage));
      final target = vm.Vector3(2, -1, 0);
      camera.lookAt(target);
      expect(camera.worldPosition.storage, orderedEquals([-7, 2, 5]));
      expectMatrix(
        camera.viewMatrix,
        vm.makeViewMatrix(vm.Vector3(-7, 2, 5), target, vm.Vector3(0, 1, 0)),
      );
    });
  }
}
