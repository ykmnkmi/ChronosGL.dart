@TestOn('chrome')
library;

import 'package:chronosgl/camera.dart' as cameras;
import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((value) => closeTo(value, 1e-5))),
  );
}

void main() {
  test('public imports expose the same standalone projection types', () {
    final Projection perspective = cameras.PerspectiveProjection(
      near: 1,
      far: 11,
    );
    final cameras.Projection orthographic = OrthographicProjection(
      left: -1,
      right: 1,
      bottom: -1,
      top: 1,
      near: -1,
      far: 1,
    );
    expect(perspective, isA<PerspectiveProjection>());
    expect(orthographic, isA<cameras.OrthographicProjection>());
    expect(perspective, isNot(isA<UniformGroup>()));
    expect(orthographic, isNot(isA<UniformGroup>()));
  });

  test(
    'directional shadow projections preserve signed depth and up selection',
    () {
      final light = DirectionalLight(
        'sun',
        vm.Vector3(1, -2, 3),
        vm.Vector3.all(1),
        vm.Vector3.zero(),
        20,
      );
      final projection = vm.makeOrthographicMatrix(-20, 20, -20, 20, -20, 20);
      for (final direction in [vm.Vector3(1, -2, 3), vm.Vector3(0, -1, 0)]) {
        light.dir.setFrom(direction);
        final up = direction.x == 0 && direction.z == 0
            ? vm.Vector3(0, 0, 1)
            : vm.Vector3(0, 1, 0);
        final expected = vm.Matrix4.copy(projection)
          ..multiply(vm.makeViewMatrix(vm.Vector3.zero(), direction, up));
        expectMatrix(light.extractShadowProjViewMatrix(), expected);
        // Legacy callers can mutate the result; the next call must rebuild it.
        light.extractShadowProjViewMatrix().setZero();
        expectMatrix(light.extractShadowProjViewMatrix(), expected);
      }
    },
  );

  test(
    'spot shadow projections preserve cone padding and mutable light pose',
    () {
      final light = SpotLight(
        'spot',
        vm.Vector3(4, 5, 6),
        vm.Vector3(-1, -2, -3),
        vm.Vector3.all(1),
        vm.Vector3.zero(),
        50,
        0.4,
        1,
        0.5,
        50,
      );
      for (final angle in [0.4, 0.6]) {
        light.angle = angle;
        final up = light.dir.x == 0 && light.dir.z == 0
            ? vm.Vector3(0, 0, 1)
            : vm.Vector3(0, 1, 0);
        final expected = vm.makePerspectiveMatrix(2.1 * angle, 1, 0.5, 50)
          ..multiply(vm.makeViewMatrix(light.pos, light.pos + light.dir, up));
        expectMatrix(light.extractShadowProjViewMatrix(), expected);
        light.extractShadowProjViewMatrix().setZero();
        expectMatrix(light.extractShadowProjViewMatrix(), expected);
        light.pos.setValues(1, 2, 3);
        light.dir.setValues(0, -1, 0);
      }
    },
  );

  test('shadow calculations reject invalid projection parameters', () {
    final directional = DirectionalLight(
      'invalid sun',
      vm.Vector3(0, -1, 0),
      vm.Vector3.all(1),
      vm.Vector3.zero(),
      0,
    );
    expect(directional.extractShadowProjViewMatrix, throwsArgumentError);
    final spot = SpotLight(
      'invalid spot',
      vm.Vector3.zero(),
      vm.Vector3(0, 0, -1),
      vm.Vector3.all(1),
      vm.Vector3.zero(),
      50,
      0.4,
      1,
      0,
      50,
    );
    expect(spot.extractShadowProjViewMatrix, throwsArgumentError);
  });
}
