import 'dart:math' as math;

import 'package:chronosgl/camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

typedef PerspectiveValues = (double, double, double, double);
typedef OrthographicValues = (double, double, double, double, double, double);

PerspectiveProjection perspectiveProjection(PerspectiveValues values) {
  final (fov, aspect, near, far) = values;
  return PerspectiveProjection(
    fovYRadians: fov,
    aspectRatio: aspect,
    near: near,
    far: far,
  );
}

PerspectiveCamera perspectiveCamera(PerspectiveValues values) {
  final (fov, aspect, near, far) = values;
  return PerspectiveCamera(
    fovYRadians: fov,
    aspectRatio: aspect,
    near: near,
    far: far,
  );
}

void setPerspective(PerspectiveCamera camera, PerspectiveValues values) {
  final (fov, aspect, near, far) = values;
  camera.setProjection(
    fovYRadians: fov,
    aspectRatio: aspect,
    near: near,
    far: far,
  );
}

OrthographicProjection orthographicProjection(OrthographicValues values) {
  final (left, right, bottom, top, near, far) = values;
  return OrthographicProjection(
    left: left,
    right: right,
    bottom: bottom,
    top: top,
    near: near,
    far: far,
  );
}

OrthographicCamera orthographicCamera(OrthographicValues values) {
  final (left, right, bottom, top, near, far) = values;
  return OrthographicCamera(
    left: left,
    right: right,
    bottom: bottom,
    top: top,
    near: near,
    far: far,
  );
}

void setOrthographic(OrthographicCamera camera, OrthographicValues values) {
  final (left, right, bottom, top, near, far) = values;
  camera.setProjection(
    left: left,
    right: right,
    bottom: bottom,
    top: top,
    near: near,
    far: far,
  );
}

List<List<double>> cameraState(Camera camera) => [
  camera.worldPosition.storage.toList(),
  camera.worldRotation.storage.toList(),
  camera.worldMatrix.storage.toList(),
  camera.viewMatrix.storage.toList(),
  camera.projectionMatrix.storage.toList(),
  camera.viewProjectionMatrix.storage.toList(),
];

void expectNdc(vm.Matrix4 matrix, vm.Vector3 point, List<double> expected) {
  final clip = matrix.transformed(vm.Vector4(point.x, point.y, point.z, 1));
  expect([
    clip.x / clip.w,
    clip.y / clip.w,
    clip.z / clip.w,
  ], orderedEquals(expected.map((value) => closeTo(value, 1e-5))));
}

void expectPerspectiveFrustum(vm.Matrix4 matrix, PerspectiveValues values) {
  final (fov, aspect, near, far) = values;
  for (final (distance, depth) in [(near, -1.0), (far, 1.0)]) {
    final halfHeight = distance * math.tan(fov / 2);
    expectNdc(matrix, vm.Vector3(0, halfHeight, -distance), [0, 1, depth]);
    expectNdc(matrix, vm.Vector3(halfHeight * aspect, 0, -distance), [
      1,
      0,
      depth,
    ]);
  }
}

void expectOrthographicVolume(vm.Matrix4 matrix, OrthographicValues values) {
  final (left, right, bottom, top, near, far) = values;
  expectNdc(matrix, vm.Vector3(left, bottom, -near), [-1, -1, -1]);
  expectNdc(matrix, vm.Vector3(right, top, -far), [1, 1, 1]);
}

void main() {
  group('named perspective parameters', () {
    test('full vertical radians work for portrait and landscape aspects', () {
      for (final aspect in [0.6, 2.4]) {
        final values = (math.pi / 3, aspect, 0.25, 40.0);
        expectPerspectiveFrustum(perspectiveProjection(values).matrix, values);
        expectPerspectiveFrustum(
          perspectiveCamera(values).projectionMatrix,
          values,
        );
      }
    });

    test('each parameter can change independently without changing pose', () {
      final camera = perspectiveCamera((0.9, 1.5, 0.5, 80));
      camera.setPosition(3, -2, 7);
      camera.lookAt(vm.Vector3(1, 4, -2));
      final pose = camera.worldMatrix.storage.toList();
      for (final values in <PerspectiveValues>[
        (1.2, 1.5, 0.5, 80),
        (1.2, 0.75, 0.5, 80),
        (1.2, 0.75, 2, 80),
        (1.2, 0.75, 2, 150),
      ]) {
        setPerspective(camera, values);
        expectPerspectiveFrustum(camera.projectionMatrix, values);
        expect(camera.worldMatrix.storage, pose);
      }
    });

    test(
      'valid small and large values have no arbitrary application limits',
      () {
        for (final values in <PerspectiveValues>[
          (1e-6, 1, 1, 10),
          (math.pi - 1e-6, 1, 1, 10),
          (1, 1e-12, 1, 10),
          (1, 1e12, 1, 10),
          (1, 1, 1e-12, 1),
          (1, 1, 1, 1e12),
        ]) {
          expectPerspectiveFrustum(
            perspectiveProjection(values).matrix,
            values,
          );
          expectPerspectiveFrustum(
            perspectiveCamera(values).projectionMatrix,
            values,
          );
        }
      },
    );

    test(
      'invalid boundaries and Float32 limits fail atomically, then recover',
      () {
        final camera = perspectiveCamera((0.9, 1.5, 0.5, 80));
        camera.setPosition(3, -2, 7);
        camera.lookAt(vm.Vector3(1, 4, -2));
        final projection = camera.projection;
        final before = cameraState(camera);
        final invalid = <PerspectiveValues>[
          (-0.0, 1, 1, 10),
          (math.pi + 1e-6, 1, 1, 10),
          (50, 1, 1, 10), // Degrees must be converted to radians.
          (1, -0.0, 1, 10),
          (1, 1, -0.0, 10),
          (1, 1, 1, 0),
          (1e-40, 1, 1, 10), // Overflow of the vertical Float32 coefficient.
          (1, 1e-40, 1, 10), // Overflow of the horizontal coefficient.
          (1, 1e46, 1, 10), // Underflow to a singular horizontal coefficient.
          (1, 1, 1e-46, 10), // Underflow to a singular depth coefficient.
          (1, 1, 1e39, 1e40), // Overflow of the depth coefficient.
        ];
        for (final value in [
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          invalid.addAll([
            (value, 1, 1, 10),
            (1, value, 1, 10),
            (1, 1, value, 10),
            (1, 1, 1, value),
          ]);
        }
        for (final values in invalid) {
          expect(() => perspectiveProjection(values), throwsArgumentError);
          expect(() => perspectiveCamera(values), throwsArgumentError);
          expect(() => setPerspective(camera, values), throwsArgumentError);
          expect(camera.projection, same(projection), reason: '$values');
          expect(cameraState(camera), before, reason: '$values');
        }
        const replacement = (1.1, 0.8, 2.0, 50.0);
        setPerspective(camera, replacement);
        expectPerspectiveFrustum(camera.projectionMatrix, replacement);
        expect(camera.worldMatrix.storage, before[2]);
      },
    );
  });

  group('named orthographic parameters', () {
    test('zero and signed near/far distances map to OpenGL depth', () {
      for (final (near, far) in [(0.0, 10.0), (-10.0, 0.0), (-10.0, -1.0)]) {
        final values = (-4.0, 7.0, -3.0, 2.0, near, far);
        expectOrthographicVolume(orthographicProjection(values).matrix, values);
        expectOrthographicVolume(
          orthographicCamera(values).projectionMatrix,
          values,
        );
      }
    });

    test('each bound changes independently while preserving pose', () {
      final camera = orthographicCamera((-4, 7, -3, 2, -10, 20));
      camera.setPosition(3, -2, 7);
      camera.lookAt(vm.Vector3(1, 4, -2));
      final pose = camera.worldMatrix.storage.toList();
      for (final values in <OrthographicValues>[
        (-2, 7, -3, 2, -10, 20),
        (-2, 8, -3, 2, -10, 20),
        (-2, 8, -1, 2, -10, 20),
        (-2, 8, -1, 4, -10, 20),
        (-2, 8, -1, 4, 0, 20),
        (-2, 8, -1, 4, 0, 30),
      ]) {
        setOrthographic(camera, values);
        expectOrthographicVolume(camera.projectionMatrix, values);
        expect(camera.worldMatrix.storage, pose);
      }
    });

    test(
      'Float32 limits are checked on every axis without partial updates',
      () {
        final camera = orthographicCamera((-4, 7, -3, 2, -10, 20));
        camera.setPosition(3, -2, 7);
        camera.lookAt(vm.Vector3(1, 4, -2));
        final projection = camera.projection;
        final before = cameraState(camera);
        final invalid = <OrthographicValues>[
          (0, 1e-40, -3, 2, -10, 20),
          (-4, 7, 0, 1e-40, -10, 20),
          (-4, 7, -3, 2, 0, 1e-40),
          (-1e46, 1e46, -3, 2, -10, 20),
          (-4, 7, -1e46, 1e46, -10, 20),
          (-4, 7, -3, 2, -1e46, 1e46),
        ];
        for (var index = 0; index < 6; index++) {
          for (final value in [
            double.nan,
            double.infinity,
            double.negativeInfinity,
          ]) {
            final bounds = <double>[-4, 7, -3, 2, -10, 20]..[index] = value;
            invalid.add((
              bounds[0],
              bounds[1],
              bounds[2],
              bounds[3],
              bounds[4],
              bounds[5],
            ));
          }
        }
        for (final values in invalid) {
          expect(() => orthographicProjection(values), throwsArgumentError);
          expect(() => orthographicCamera(values), throwsArgumentError);
          expect(() => setOrthographic(camera, values), throwsArgumentError);
          expect(camera.projection, same(projection), reason: '$values');
          expect(cameraState(camera), before, reason: '$values');
        }
        const replacement = (-2.0, 8.0, -1.0, 4.0, 0.0, 30.0);
        setOrthographic(camera, replacement);
        expectOrthographicVolume(camera.projectionMatrix, replacement);
        expect(camera.worldMatrix.storage, before[2]);
      },
    );
  });
}
