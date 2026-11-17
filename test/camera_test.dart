import 'dart:math' as math;

import 'package:chronosgl/camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

const tolerance = 1e-5;

void expectVector(vm.Vector3 actual, List<double> expected) {
  expect(
    actual.storage,
    orderedEquals(expected.map((value) => closeTo(value, tolerance))),
  );
}

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((value) => closeTo(value, tolerance))),
  );
}

vm.Vector3 ndc(vm.Matrix4 matrix, double x, double y, double z) {
  final clip = matrix.transformed(vm.Vector4(x, y, z, 1));
  return vm.Vector3(clip.x / clip.w, clip.y / clip.w, clip.z / clip.w);
}

PerspectiveCamera perspective({
  vm.Vector3? position,
  vm.Quaternion? rotation,
}) =>
    PerspectiveCamera(near: 1, far: 11, position: position, rotation: rotation);

OrthographicCamera orthographic({
  vm.Vector3? position,
  vm.Quaternion? rotation,
}) => OrthographicCamera(
  left: -2,
  right: 6,
  bottom: -3,
  top: 1,
  near: -5,
  far: 15,
  position: position,
  rotation: rotation,
);

void main() {
  final factories =
      <
        String,
        Camera Function({vm.Vector3? position, vm.Quaternion? rotation})
      >{'perspective': perspective, 'orthographic': orthographic};

  for (final entry in factories.entries) {
    group(entry.key, () {
      final create = entry.value;

      test('common contract starts at the origin looking down -Z', () {
        final Camera camera = create();
        expectVector(camera.worldPosition, [0, 0, 0]);
        expectMatrix(camera.worldMatrix, vm.Matrix4.identity());
        expectMatrix(camera.viewMatrix, vm.Matrix4.identity());
        expectMatrix(camera.viewProjectionMatrix, camera.projectionMatrix);
        expectVector(camera.worldMatrix.transformed3(vm.Vector3(0, 0, -1)), [
          0,
          0,
          -1,
        ]);
      });

      test('constructor copies position and normalizes rotation', () {
        final position = vm.Vector3(2, 3, 4);
        final rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.pi / 2,
        )..scale(3);
        final camera = create(position: position, rotation: rotation);
        position.setZero();
        rotation.setValues(0, 0, 0, 1);
        expectVector(camera.worldPosition, [2, 3, 4]);
        expect(camera.worldRotation.length, closeTo(1, tolerance));
        expectVector(camera.worldMatrix.transformed3(vm.Vector3(0, 0, -2)), [
          0,
          3,
          4,
        ]);
        expectVector(camera.viewMatrix.transformed3(vm.Vector3(0, 3, 4)), [
          0,
          0,
          -2,
        ]);
      });

      test('lookAt preserves eye position and produces an inverse view', () {
        final camera = create()..setPosition(0, 0, 10);
        camera.lookAt(vm.Vector3.zero());
        expectVector(camera.worldPosition, [0, 0, 10]);
        expectVector(camera.viewMatrix.transformed3(camera.worldPosition), [
          0,
          0,
          0,
        ]);
        expectVector(camera.viewMatrix.transformed3(vm.Vector3.zero()), [
          0,
          0,
          -10,
        ]);

        camera.setPosition(3, 4, 12);
        camera.lookAt(vm.Vector3.zero());
        expectVector(camera.worldPosition, [3, 4, 12]);
        expectVector(camera.viewMatrix.transformed3(vm.Vector3.zero()), [
          0,
          0,
          -13,
        ]);
        expectMatrix(
          camera.viewMatrix..multiply(camera.worldMatrix),
          vm.Matrix4.identity(),
        );
        expectMatrix(
          camera.worldMatrix..multiply(camera.viewMatrix),
          vm.Matrix4.identity(),
        );
      });

      test('lookAt uses a world target and a custom world up hint', () {
        final camera = create(position: vm.Vector3(2, 3, 4));
        camera.lookAt(vm.Vector3(2, 8, 4), upHint: vm.Vector3(0, 0, 1));
        expectVector(camera.worldPosition, [2, 3, 4]);
        expectVector(camera.worldMatrix.transformed3(vm.Vector3(0, 0, -1)), [
          2,
          4,
          4,
        ]);
        expectVector(camera.worldMatrix.transformed3(vm.Vector3(0, 1, 0)), [
          2,
          3,
          5,
        ]);
        expectVector(camera.viewMatrix.transformed3(vm.Vector3(2, 8, 4)), [
          0,
          0,
          -5,
        ]);
      });

      test('pose setters are immediate and preserve the other component', () {
        final camera = create()..setPosition(4, 5, 6);
        final rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.pi / 2,
        );
        camera.setRotation(rotation);
        rotation.setValues(0, 0, 0, 1);
        expectVector(camera.worldPosition, [4, 5, 6]);
        final orientation = camera.worldRotation.storage.toList();
        final position = vm.Vector3(7, 8, 9);
        camera.setPositionFromVector(position);
        position.setZero();
        expectVector(camera.worldPosition, [7, 8, 9]);
        expect(camera.worldRotation.storage, orderedEquals(orientation));
        expectVector(camera.viewMatrix.transformed3(vm.Vector3(5, 8, 9)), [
          0,
          0,
          -2,
        ]);
        expectMatrix(
          camera.viewProjectionMatrix,
          camera.projectionMatrix..multiply(camera.viewMatrix),
        );
      });

      test('all returned state is independently owned', () {
        final camera = create(position: vm.Vector3(1, 2, 3));
        final world = camera.worldMatrix;
        final view = camera.viewMatrix;
        final projection = camera.projectionMatrix;
        final combined = camera.viewProjectionMatrix;
        camera.worldPosition.setZero();
        camera.worldRotation.setValues(0, 0, 0, 0);
        camera.worldMatrix.setZero();
        camera.viewMatrix.setZero();
        camera.projectionMatrix.setZero();
        camera.viewProjectionMatrix.setZero();
        expectVector(camera.worldPosition, [1, 2, 3]);
        expect(camera.worldRotation.w, 1);
        expectMatrix(camera.worldMatrix, world);
        expectMatrix(camera.viewMatrix, view);
        expectMatrix(camera.projectionMatrix, projection);
        expectMatrix(camera.viewProjectionMatrix, combined);
        camera.setPosition(4, 5, 6);
        expectVector(world.getTranslation(), [1, 2, 3]);
        expectVector(view.getTranslation(), [-1, -2, -3]);
      });

      test('invalid pose updates and lookAt leave the entire pose intact', () {
        final camera = create(position: vm.Vector3(0, 0, 10));
        final before = camera.worldMatrix;
        final invalid = <void Function()>[
          () => camera.setPosition(double.nan, 0, 0),
          () => camera.setPosition(1e100, 0, 0),
          () => camera.setPositionFromVector(vm.Vector3(0, double.infinity, 0)),
          () => camera.setRotation(vm.Quaternion(0, 0, 0, 0)),
          () => camera.setRotation(vm.Quaternion(double.nan, 0, 0, 1)),
          () => camera.lookAt(camera.worldPosition),
          () => camera.lookAt(vm.Vector3(double.nan, 0, 0)),
          () => camera.lookAt(vm.Vector3.zero(), upHint: vm.Vector3.zero()),
          () => camera.lookAt(vm.Vector3.zero(), upHint: vm.Vector3(0, 0, 1)),
          () =>
              camera.lookAt(vm.Vector3.zero(), upHint: vm.Vector3(0, 1e-7, 1)),
        ];
        for (final call in invalid) {
          expect(call, throwsArgumentError);
          expectMatrix(camera.worldMatrix, before);
          expectMatrix(
            camera.viewMatrix..multiply(before),
            vm.Matrix4.identity(),
          );
        }
        expect(
          () => create(position: vm.Vector3(double.infinity, 0, 0)),
          throwsArgumentError,
        );
        expect(
          () => create(rotation: vm.Quaternion(0, 0, 0, 0)),
          throwsArgumentError,
        );
      });

      test('camera instances own separate poses and projection snapshots', () {
        final first = create();
        final second = create();
        first.setPosition(1, 2, 3);
        first.lookAt(vm.Vector3.zero());
        first.projectionMatrix.setZero();
        expectMatrix(second.worldMatrix, vm.Matrix4.identity());
        expectMatrix(second.projectionMatrix, create().projectionMatrix);
      });
    });
  }

  group('perspective projection', () {
    test('defaults preserve the full 50 degree vertical FOV', () {
      final camera = perspective();
      expect(camera.fovYRadians, 50 * math.pi / 180);
      expect(camera.aspectRatio, 1);
      expect(camera.near, 1);
      expect(camera.far, 11);
      expectVector(
        ndc(camera.projectionMatrix, 0, math.tan(25 * math.pi / 180), -1),
        [0, 1, -1],
      );
    });

    test('frustum corners and clipping planes map to OpenGL NDC', () {
      final camera = PerspectiveCamera(
        fovYRadians: math.pi / 2,
        aspectRatio: 2,
        near: 1,
        far: 11,
      );
      final matrix = camera.projectionMatrix;
      expectVector(ndc(matrix, -2, -1, -1), [-1, -1, -1]);
      expectVector(ndc(matrix, 2, 1, -1), [1, 1, -1]);
      expectVector(ndc(matrix, -22, -11, -11), [-1, -1, 1]);
      expectVector(ndc(matrix, 22, 11, -11), [1, 1, 1]);
      expect(ndc(matrix, 0, 0, -0.5).z, lessThan(-1));
      expect(ndc(matrix, 0, 0, -12).z, greaterThan(1));
    });

    test(
      'combined matrix projects world coordinates through the camera pose',
      () {
        final camera =
            PerspectiveCamera(
                fovYRadians: math.pi / 2,
                aspectRatio: 2,
                near: 1,
                far: 11,
              )
              ..setPosition(10, 0, 0)
              ..lookAt(vm.Vector3.zero());
        expectVector(ndc(camera.viewProjectionMatrix, 9, 0, 0), [0, 0, -1]);
        expectVector(ndc(camera.viewProjectionMatrix, -1, 0, 0), [0, 0, 1]);
        expectVector(ndc(camera.viewProjectionMatrix, 9, 1, -2), [1, 1, -1]);
      },
    );

    test('projection changes preserve pose and prior matrix snapshots', () {
      final camera = perspective(position: vm.Vector3(1, 2, 3));
      final pose = camera.worldMatrix;
      final before = camera.projectionMatrix;
      camera.setProjection(
        fovYRadians: math.pi / 2,
        aspectRatio: 2,
        near: 2,
        far: 22,
      );
      expectMatrix(camera.worldMatrix, pose);
      expectMatrix(before, perspective().projectionMatrix);
      expectVector(ndc(camera.projectionMatrix, 4, 2, -2), [1, 1, -1]);
      expect(camera.fovYRadians, math.pi / 2);
      expect(camera.aspectRatio, 2);
      expect(camera.near, 2);
      expect(camera.far, 22);
      camera.setProjection(
        fovYRadians: camera.fovYRadians,
        aspectRatio: 1,
        near: camera.near,
        far: camera.far,
      );
      expectVector(ndc(camera.projectionMatrix, 2, 2, -2), [1, 1, -1]);
    });

    test('invalid parameters fail atomically in constructors and updates', () {
      final camera = perspective();
      final before = camera.projectionMatrix;
      final invalid = <(double, double, double, double)>[
        (0, 1, 1, 11),
        (-1, 1, 1, 11),
        (math.pi, 1, 1, 11),
        (double.nan, 1, 1, 11),
        (double.infinity, 1, 1, 11),
        (1, 0, 1, 11),
        (1, -1, 1, 11),
        (1, double.nan, 1, 11),
        (1, double.infinity, 1, 11),
        (1, 1, 0, 11),
        (1, 1, -1, 11),
        (1, 1, 11, 11),
        (1, 1, 12, 11),
        (1, 1, double.nan, 11),
        (1, 1, 1, double.nan),
        (1, 1, 1, double.infinity),
        (1e-100, 1, 1, 11),
        (1, 1e100, 1, 11),
        (1, 1, 1e-100, 11),
      ];
      for (final (fov, aspect, near, far) in invalid) {
        expect(
          () => PerspectiveCamera(
            fovYRadians: fov,
            aspectRatio: aspect,
            near: near,
            far: far,
          ),
          throwsArgumentError,
        );
        expect(
          () => camera.setProjection(
            fovYRadians: fov,
            aspectRatio: aspect,
            near: near,
            far: far,
          ),
          throwsArgumentError,
        );
        expectMatrix(camera.projectionMatrix, before);
        expect(
          [camera.fovYRadians, camera.aspectRatio, camera.near, camera.far],
          [50 * math.pi / 180, 1, 1, 11],
        );
      }
    });
  });

  group('orthographic projection', () {
    test('asymmetric bounds and signed depth map to OpenGL NDC', () {
      final camera = orthographic();
      expect(
        [
          camera.left,
          camera.right,
          camera.bottom,
          camera.top,
          camera.near,
          camera.far,
        ],
        [-2, 6, -3, 1, -5, 15],
      );
      final matrix = camera.projectionMatrix;
      expectVector(ndc(matrix, -2, -3, 5), [-1, -1, -1]);
      expectVector(ndc(matrix, 6, 1, -15), [1, 1, 1]);
      expectVector(ndc(matrix, 2, -1, -5), [0, 0, 0]);
      expectVector(ndc(matrix, 6, 1, 5), [1, 1, -1]);
      expect(ndc(matrix, 0, 0, 6).z, lessThan(-1));
      expect(ndc(matrix, 0, 0, -16).z, greaterThan(1));
    });

    test('combined matrix uses the same world pose as perspective', () {
      final camera = orthographic()
        ..setPosition(10, 0, 0)
        ..lookAt(vm.Vector3.zero());
      expectVector(ndc(camera.viewProjectionMatrix, 15, -3, 2), [-1, -1, -1]);
      expectVector(ndc(camera.viewProjectionMatrix, -5, 1, -6), [1, 1, 1]);
    });

    test(
      'updates preserve pose, snapshots and explicit bounds; zero near works',
      () {
        final camera = orthographic(position: vm.Vector3(1, 2, 3));
        final pose = camera.worldMatrix;
        final before = camera.projectionMatrix;
        camera.setProjection(
          left: 2,
          right: 10,
          bottom: 3,
          top: 7,
          near: 0,
          far: 10,
        );
        expectMatrix(camera.worldMatrix, pose);
        expectMatrix(before, orthographic().projectionMatrix);
        expectVector(ndc(camera.projectionMatrix, 2, 3, 0), [-1, -1, -1]);
        expectVector(ndc(camera.projectionMatrix, 10, 7, -10), [1, 1, 1]);
        camera.setPosition(9, 8, 7);
        expect(
          [
            camera.left,
            camera.right,
            camera.bottom,
            camera.top,
            camera.near,
            camera.far,
          ],
          [2, 10, 3, 7, 0, 10],
        );
      },
    );

    test('invalid bounds fail atomically in constructors and updates', () {
      final camera = orthographic();
      final before = camera.projectionMatrix;
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
      for (final values in invalid) {
        final [left, right, bottom, top, near, far] = values;
        expect(
          () => OrthographicCamera(
            left: left,
            right: right,
            bottom: bottom,
            top: top,
            near: near,
            far: far,
          ),
          throwsArgumentError,
        );
        expect(
          () => camera.setProjection(
            left: left,
            right: right,
            bottom: bottom,
            top: top,
            near: near,
            far: far,
          ),
          throwsArgumentError,
        );
        expectMatrix(camera.projectionMatrix, before);
        expect(
          [
            camera.left,
            camera.right,
            camera.bottom,
            camera.top,
            camera.near,
            camera.far,
          ],
          [-2, 6, -3, 1, -5, 15],
        );
      }
    });
  });
}
