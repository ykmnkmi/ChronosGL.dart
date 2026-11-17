import 'dart:math' as math;

import 'package:chronosgl/camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void expectComponents(Iterable<double> actual, Iterable<double> expected) {
  expect(actual, orderedEquals(expected.map((value) => closeTo(value, 1e-4))));
}

// Rodrigues' formula provides a reference without using matrix composition,
// inversion, or quaternion-vector multiplication from the implementation.
vm.Vector3 rotate(vm.Vector3 value, vm.Vector3 axis, double angle) {
  final cosine = math.cos(angle);
  return value * cosine +
      axis.cross(value) * math.sin(angle) +
      axis * (axis.dot(value) * (1 - cosine));
}

void main() {
  final factories = <String, Camera Function()>{
    'perspective': () => PerspectiveCamera(near: 1, far: 100),
    'orthographic': () => OrthographicCamera(
      left: -2,
      right: 6,
      bottom: -3,
      top: 1,
      near: -5,
      far: 15,
    ),
  };

  for (final entry in factories.entries) {
    group(entry.key, () {
      final create = entry.value;

      test(
        'translation moves the eye to the origin and preserves directions',
        () {
          final camera = create();
          for (final position in [
            vm.Vector3.zero(),
            vm.Vector3(0, 0, 10),
            vm.Vector3(7, -3, 5),
          ]) {
            camera.setPositionFromVector(position);
            final view = camera.viewMatrix;
            expectComponents(
              view.storage,
              vm.Matrix4.translation(-position).storage,
            );
            expectComponents(view.transformed3(position).storage, [0, 0, 0]);
            expectComponents(
              view.transformed(vm.Vector4(2, -4, -6, 0)).storage,
              [2, -4, -6, 0],
            );
          }
        },
      );

      test('yaw and local roll rotate the negative eye into view translation', () {
        // R = Ry(pi/2) * Rz(pi/2): local X -> +Y, Y -> +Z, Z -> +X.
        // The expected coordinates below are derived from these axis mappings.
        final camera = create()
          ..setPosition(7, -3, 5)
          ..setRotation(
            vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2) *
                vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
          );
        final world = camera.worldMatrix;
        final view = camera.viewMatrix;
        expectComponents(world.transformed3(vm.Vector3(4, 2, -6)).storage, [
          1,
          1,
          7,
        ]);
        expectComponents(view.transformed3(vm.Vector3(1, 1, 7)).storage, [
          4,
          2,
          -6,
        ]);
        expectComponents(view.getTranslation().storage, [3, -5, -7]);
        expectComponents(view.transformed3(camera.worldPosition).storage, [
          0,
          0,
          0,
        ]);
        for (final (worldDirection, localDirection) in [
          (vm.Vector4(0, 1, 0, 0), [1.0, 0.0, 0.0, 0.0]),
          (vm.Vector4(0, 0, 1, 0), [0.0, 1.0, 0.0, 0.0]),
          (vm.Vector4(-1, 0, 0, 0), [0.0, 0.0, -1.0, 0.0]),
        ]) {
          expectComponents(
            view.transformed(worldDirection).storage,
            localDirection,
          );
        }
      });

      test(
        'arbitrary poses match an independent inverse rotation reference',
        () {
          final camera = create();
          final random = math.Random(35);
          double coordinate() => random.nextDouble() * 20 - 10;

          for (var sample = 0; sample < 64; sample++) {
            final eye = vm.Vector3(coordinate(), coordinate(), coordinate());
            final axis = vm.Vector3(coordinate(), coordinate(), coordinate())
              ..normalize();
            final angle = (random.nextDouble() * 2 - 1) * math.pi;
            final point = vm.Vector3(coordinate(), coordinate(), coordinate());
            final direction = vm.Vector3(
              coordinate(),
              coordinate(),
              coordinate(),
            );
            camera
              ..setPositionFromVector(eye)
              ..setRotation(vm.Quaternion.axisAngle(axis, angle));
            final world = camera.worldMatrix;
            final view = camera.viewMatrix;

            expectComponents(
              view.transformed3(point).storage,
              rotate(point - eye, axis, -angle).storage,
            );
            expectComponents(
              view
                  .transformed(
                    vm.Vector4(direction.x, direction.y, direction.z, 0),
                  )
                  .storage,
              [...rotate(direction, axis, -angle).storage, 0],
            );
            expectComponents(view.transformed3(eye).storage, [0, 0, 0]);
            expectComponents(
              (vm.Matrix4.copy(view)..multiply(world)).storage,
              vm.Matrix4.identity().storage,
            );
            expectComponents(
              (vm.Matrix4.copy(world)..multiply(view)).storage,
              vm.Matrix4.identity().storage,
            );
            expectComponents(
              world.transformed3(view.transformed3(point)).storage,
              point.storage,
            );
            expectComponents(
              view.transformed3(world.transformed3(point)).storage,
              point.storage,
            );
          }
        },
      );

      test('large finite translations retain a finite inverse and basis', () {
        final camera = create()
          ..setPosition(1e30, -2e30, 3e30)
          ..setRotation(
            vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
          );
        final view = camera.viewMatrix;
        expect(view.storage.every((value) => value.isFinite), isTrue);
        // Relative checks account for the precision of Float32 translations.
        expectComponents(
          view.getTranslation().storage.map((value) => value / 1e30),
          [2, 1, -3],
        );
        expectComponents(view.transformed(vm.Vector4(0, 1, 0, 0)).storage, [
          1,
          0,
          0,
          0,
        ]);
        expectComponents(
          view.transformed3(camera.worldPosition).storage.map((v) => v / 1e30),
          [0, 0, 0],
        );
      });
    });
  }

  test('projection changes leave the shared world-to-view calculation intact', () {
    final perspective = PerspectiveCamera(near: 1, far: 100);
    final orthographic = OrthographicCamera(
      left: -2,
      right: 6,
      bottom: -3,
      top: 1,
      near: -5,
      far: 15,
    );
    for (final camera in [perspective, orthographic]) {
      camera
        ..setPosition(7, -3, 5)
        ..setRotation(
          vm.Quaternion.axisAngle(vm.Vector3(1, 2, 3)..normalize(), 0.7),
        );
    }
    final originalView = perspective.viewMatrix;
    perspective.setProjection(
      fovYRadians: math.pi / 3,
      aspectRatio: 2,
      near: 0.25,
      far: 50,
    );
    orthographic.setProjection(
      left: -10,
      right: 20,
      bottom: -5,
      top: 5,
      near: 0,
      far: 50,
    );
    for (final camera in [perspective, orthographic]) {
      expect(camera.viewMatrix.storage, orderedEquals(originalView.storage));
      // World -> clip agrees with the explicit world -> view -> clip pipeline.
      final worldPoint = vm.Vector4(-2, 1, -4, 1);
      expectComponents(
        camera.viewProjectionMatrix.transformed(worldPoint).storage,
        camera.projectionMatrix
            .transformed(originalView.transformed(worldPoint))
            .storage,
      );
    }
  });
}
