import 'dart:math' as math;

import 'package:chronosgl/camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

const tolerance = 1e-5;

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((value) => closeTo(value, tolerance))),
  );
}

void expectNdc(vm.Matrix4 matrix, vm.Vector3 point, List<double> expected) {
  final clip = matrix.transformed(vm.Vector4(point.x, point.y, point.z, 1));
  expect([
    clip.x / clip.w,
    clip.y / clip.w,
    clip.z / clip.w,
  ], orderedEquals(expected.map((value) => closeTo(value, tolerance))));
}

void main() {
  group('standalone perspective projection', () {
    test('default FOV is a full vertical angle in radians', () {
      final projection = PerspectiveProjection(near: 1, far: 11);
      expect(projection.fovYRadians, 50 * math.pi / 180);
      expect(projection.aspectRatio, 1);
      expect(projection.near, 1);
      expect(projection.far, 11);
      expectNdc(
        projection.matrix,
        vm.Vector3(0, math.tan(25 * math.pi / 180), -1),
        [0, 1, -1],
      );
    });

    test('frustum corners and clipping planes work without a camera', () {
      final Projection projection = PerspectiveProjection(
        fovYRadians: math.pi / 2,
        aspectRatio: 2,
        near: 1,
        far: 11,
      );
      final matrix = projection.matrix;
      expectNdc(matrix, vm.Vector3(-2, -1, -1), [-1, -1, -1]);
      expectNdc(matrix, vm.Vector3(2, 1, -1), [1, 1, -1]);
      expectNdc(matrix, vm.Vector3(-22, -11, -11), [-1, -1, 1]);
      expectNdc(matrix, vm.Vector3(22, 11, -11), [1, 1, 1]);
    });

    test(
      'invalid ranges and unrepresentable Float32 matrices are rejected',
      () {
        final invalid = <(double, double, double, double)>[
          (0, 1, 1, 11),
          (-1, 1, 1, 11),
          (math.pi, 1, 1, 11),
          (1, 0, 1, 11),
          (1, -1, 1, 11),
          (1, 1, 0, 11),
          (1, 1, -1, 11),
          (1, 1, 11, 11),
          (1, 1, 12, 11),
          (1e-100, 1, 1, 11),
          (1, 1e100, 1, 11),
          (1, 1, 1e-100, 11),
        ];
        for (final value in [
          double.nan,
          double.infinity,
          double.negativeInfinity,
        ]) {
          invalid.addAll([
            (value, 1, 1, 11),
            (1, value, 1, 11),
            (1, 1, value, 11),
            (1, 1, 1, value),
          ]);
        }
        for (final (fov, aspect, near, far) in invalid) {
          expect(
            () => PerspectiveProjection(
              fovYRadians: fov,
              aspectRatio: aspect,
              near: near,
              far: far,
            ),
            throwsArgumentError,
          );
        }
      },
    );
  });

  group('standalone orthographic projection', () {
    test('asymmetric bounds and signed depth work without a camera', () {
      final projection = OrthographicProjection(
        left: -2,
        right: 6,
        bottom: -3,
        top: 1,
        near: -5,
        far: 15,
      );
      expect(
        [
          projection.left,
          projection.right,
          projection.bottom,
          projection.top,
          projection.near,
          projection.far,
        ],
        [-2, 6, -3, 1, -5, 15],
      );
      final matrix = projection.matrix;
      expectNdc(matrix, vm.Vector3(-2, -3, 5), [-1, -1, -1]);
      expectNdc(matrix, vm.Vector3(6, 1, -15), [1, 1, 1]);
      expectNdc(matrix, vm.Vector3(2, -1, -5), [0, 0, 0]);
    });

    test('zero near supports a shadow volume starting at the light', () {
      final projection = OrthographicProjection(
        left: -2,
        right: 2,
        bottom: -2,
        top: 2,
        near: 0,
        far: 10,
      );
      expectNdc(projection.matrix, vm.Vector3.zero(), [0, 0, -1]);
      expectNdc(projection.matrix, vm.Vector3(0, 0, -10), [0, 0, 1]);
    });

    test(
      'invalid bounds and unrepresentable Float32 matrices are rejected',
      () {
        final invalid = <List<double>>[
          [6, 6, -3, 1, -5, 15],
          [7, 6, -3, 1, -5, 15],
          [-2, 6, 1, 1, -5, 15],
          [-2, 6, 2, 1, -5, 15],
          [-2, 6, -3, 1, 15, 15],
          [-2, 6, -3, 1, 16, 15],
          [0, 1e-100, -3, 1, -5, 15],
          [-1e100, 1e100, -3, 1, -5, 15],
        ];
        for (var index = 0; index < 6; index++) {
          for (final value in [
            double.nan,
            double.infinity,
            double.negativeInfinity,
          ]) {
            invalid.add(<double>[-2, 6, -3, 1, -5, 15]..[index] = value);
          }
        }
        for (final [left, right, bottom, top, near, far] in invalid) {
          expect(
            () => OrthographicProjection(
              left: left,
              right: right,
              bottom: bottom,
              top: top,
              near: near,
              far: far,
            ),
            throwsArgumentError,
          );
        }
      },
    );
  });

  final projections = <String, Projection>{
    'perspective': PerspectiveProjection(
      fovYRadians: math.pi / 2,
      aspectRatio: 2,
      near: 1,
      far: 11,
    ),
    'orthographic': OrthographicProjection(
      left: -2,
      right: 2,
      bottom: -1,
      top: 1,
      near: -5,
      far: 15,
    ),
  };
  for (final entry in projections.entries) {
    test(
      '${entry.key} snapshots and copy destinations are independently owned',
      () {
        final projection = entry.value;
        final before = projection.matrix;
        final snapshot = projection.matrix;
        snapshot.setZero();
        expectMatrix(projection.matrix, before);
        final destination = vm.Matrix4.zero()..storage.fillRange(0, 16, 7);
        projection.copyMatrixInto(destination);
        expectMatrix(destination, before);
        destination.setZero();
        expectMatrix(projection.matrix, before);
      },
    );

    test(
      '${entry.key} composes with a light view without changing either input',
      () {
        final projection = entry.value;
        final view = vm.makeViewMatrix(
          vm.Vector3(10, 0, 0),
          vm.Vector3.zero(),
          vm.Vector3(0, 1, 0),
        );
        final beforeView = vm.Matrix4.copy(view);
        final beforeProjection = projection.matrix;
        final lightMatrix = projection.matrix..multiply(view);
        if (projection is PerspectiveProjection) {
          expectNdc(lightMatrix, vm.Vector3(9, 1, -2), [1, 1, -1]);
          expectNdc(lightMatrix, vm.Vector3(-1, 11, -22), [1, 1, 1]);
        } else {
          expectNdc(lightMatrix, vm.Vector3(15, 1, -2), [1, 1, -1]);
          expectNdc(lightMatrix, vm.Vector3(-5, 1, -2), [1, 1, 1]);
        }
        expectMatrix(view, beforeView);
        expectMatrix(projection.matrix, beforeProjection);
      },
    );
  }

  test('perspective cameras can share a projection with independent poses and updates', () {
    final projection = PerspectiveProjection(near: 1, far: 11);
    final first = PerspectiveCamera.fromProjection(
      projection,
      position: vm.Vector3(0, 0, 10),
    );
    final second = PerspectiveCamera.fromProjection(
      projection,
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2),
    );
    expect(first.projection, same(projection));
    expect(second.projection, same(projection));
    expectMatrix(
      first.viewProjectionMatrix,
      projection.matrix..multiply(vm.Matrix4.translationValues(0, 0, -10)),
    );
    expectNdc(second.viewProjectionMatrix, vm.Vector3(-1, 0, 0), [0, 0, -1]);
    final secondView = second.viewMatrix;
    first.setProjection(
      fovYRadians: math.pi / 2,
      aspectRatio: 2,
      near: 2,
      far: 22,
    );
    first.setPosition(1, 2, 3);
    expect(first.projection, isNot(same(projection)));
    expect(second.projection, same(projection));
    expectMatrix(second.viewMatrix, secondView);
    expect(projection.near, 1);
    expectNdc(first.projection.matrix, vm.Vector3(4, 2, -2), [1, 1, -1]);
    final replacement = first.projection;
    expect(
      () =>
          first.setProjection(fovYRadians: 0, aspectRatio: 2, near: 2, far: 22),
      throwsArgumentError,
    );
    expect(first.projection, same(replacement));
  });

  test('orthographic cameras can share a projection with independent poses and updates', () {
    final projection = OrthographicProjection(
      left: -2,
      right: 2,
      bottom: -1,
      top: 1,
      near: -5,
      far: 15,
    );
    final first = OrthographicCamera.fromProjection(
      projection,
      position: vm.Vector3(0, 0, 10),
    );
    final second = OrthographicCamera.fromProjection(
      projection,
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2),
    );
    expect(first.projection, same(projection));
    expect(second.projection, same(projection));
    expectMatrix(
      first.viewProjectionMatrix,
      projection.matrix..multiply(vm.Matrix4.translationValues(0, 0, -10)),
    );
    expectNdc(second.viewProjectionMatrix, vm.Vector3(-15, 0, 0), [0, 0, 1]);
    final secondView = second.viewMatrix;
    first.setProjection(
      left: 2,
      right: 10,
      bottom: 3,
      top: 7,
      near: 0,
      far: 10,
    );
    first.setPosition(1, 2, 3);
    expect(first.projection, isNot(same(projection)));
    expect(second.projection, same(projection));
    expectMatrix(second.viewMatrix, secondView);
    expect(projection.near, -5);
    expectNdc(first.projection.matrix, vm.Vector3(10, 7, -10), [1, 1, 1]);
    final replacement = first.projection;
    expect(
      () => first.setProjection(
        left: 2,
        right: 2,
        bottom: 3,
        top: 7,
        near: 0,
        far: 10,
      ),
      throwsArgumentError,
    );
    expect(first.projection, same(replacement));
  });
}
