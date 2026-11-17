import 'dart:math' as math;

import 'package:chronosgl/camera.dart';
import 'package:chronosgl/core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((value) => closeTo(value, 1e-5))),
  );
}

// A projection may fail independently of the pose and view calculations.
class UnavailableProjectionCamera extends Camera {
  @override
  vm.Matrix4 get projectionMatrix => throw StateError('Projection unavailable');
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

      test('matrix read order never feeds back into subsequent pose edits', () {
        final withReads = create();
        final withoutReads = create();
        final projection = withReads.projectionMatrix;
        for (var step = 0; step < 40; step++) {
          for (final camera in [withReads, withoutReads]) {
            camera.setPosition(step / 2, 3, 12 - step / 4);
            camera.lookAt(vm.Vector3(-2, 1, -5));
          }
          final position = withReads.worldPosition;
          final rotation = withReads.worldRotation;
          // Destroy each returned snapshot before editing the pose again.
          withReads.viewProjectionMatrix.setZero();
          withReads.viewMatrix.setZero();
          withReads.worldMatrix.setZero();
          withReads.worldPosition.setZero();
          withReads.worldRotation.setValues(0, 0, 0, 0);
          expect(
            withReads.worldPosition.storage,
            orderedEquals(position.storage),
          );
          expect(
            withReads.worldRotation.storage,
            orderedEquals(rotation.storage),
          );
          expect(
            withReads.worldMatrix.storage,
            orderedEquals(withoutReads.worldMatrix.storage),
          );

          final nextRotation = vm.Quaternion.axisAngle(
            vm.Vector3(1, 2, -1)..normalize(),
            step / 10,
          );
          for (final camera in [withReads, withoutReads]) {
            camera.setRotation(nextRotation);
            camera.setPositionFromVector(position + vm.Vector3(1, -2, 3));
          }
          expect(
            withReads.worldMatrix.storage,
            orderedEquals(withoutReads.worldMatrix.storage),
          );
          expectMatrix(
            withReads.viewMatrix..multiply(withReads.worldMatrix),
            vm.Matrix4.identity(),
          );
        }
        expectMatrix(withReads.projectionMatrix, projection);
      });

      test(
        'moving after lookAt preserves orientation, without tracking a target',
        () {
          final camera = create()..setPosition(3, 4, 12);
          final target = vm.Vector3(-2, 1, -5);
          final upHint = vm.Vector3(1, 2, 0);
          camera.lookAt(target, upHint: upHint);
          final rotation = camera.worldRotation;
          final oldWorld = camera.worldMatrix;
          final oldView = camera.viewMatrix;
          target.setValues(100, 200, 300);
          upHint.setZero();

          camera.setPosition(-7, 8, 9);
          expect(camera.worldPosition.storage, orderedEquals([-7, 8, 9]));
          expect(camera.worldRotation.storage, orderedEquals(rotation.storage));
          expectMatrix(
            camera.worldMatrix,
            vm.Matrix4.copy(oldWorld)..setTranslation(vm.Vector3(-7, 8, 9)),
          );
          expect(oldWorld.getTranslation().storage, orderedEquals([3, 4, 12]));
          expectMatrix(oldView..multiply(oldWorld), vm.Matrix4.identity());
          expectMatrix(
            camera.viewMatrix..multiply(camera.worldMatrix),
            vm.Matrix4.identity(),
          );
        },
      );

      test(
        'failed view calculation leaves finite pose readable and editable',
        () {
          final camera = create()
            ..setPosition(3e38, 3e38, 0)
            ..setRotation(
              vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 4),
            );
          final position = camera.worldPosition;
          final rotation = camera.worldRotation;
          final world = camera.worldMatrix;
          final projection = camera.projectionMatrix;
          expect(world.storage.every((value) => value.isFinite), isTrue);
          for (var attempt = 0; attempt < 3; attempt++) {
            expect(() => camera.viewMatrix, throwsStateError);
            expect(() => camera.viewProjectionMatrix, throwsStateError);
            expect(
              camera.worldPosition.storage,
              orderedEquals(position.storage),
            );
            expect(
              camera.worldRotation.storage,
              orderedEquals(rotation.storage),
            );
            expect(camera.worldMatrix.storage, orderedEquals(world.storage));
            expectMatrix(camera.projectionMatrix, projection);
          }

          // Orientation can be changed even while the old view is unrepresentable.
          camera.setRotation(vm.Quaternion.identity());
          expect(camera.worldPosition.storage, orderedEquals(position.storage));
          expect(
            camera.viewMatrix.storage.every((value) => value.isFinite),
            isTrue,
          );
          camera.setPosition(4, 5, 6);
          camera.lookAt(vm.Vector3.zero());
          expectMatrix(
            camera.viewMatrix..multiply(camera.worldMatrix),
            vm.Matrix4.identity(),
          );
        },
      );

      test('invalid edits after matrix reads retain exact pose components', () {
        final camera = create()..setPosition(3, 4, 12);
        camera.lookAt(vm.Vector3(-2, 1, -5));
        final position = camera.worldPosition;
        final rotation = camera.worldRotation;
        final view = camera.viewMatrix;
        final invalid = <void Function()>[
          () => camera.setPosition(1, 2, 1e100),
          () => camera.setPositionFromVector(vm.Vector3(1, double.nan, 3)),
          () => camera.setRotation(vm.Quaternion(0, 0, 0, 0)),
          () => camera.setRotation(vm.Quaternion(0, double.infinity, 0, 1)),
          () => camera.lookAt(position),
          () => camera.lookAt(vm.Vector3.zero(), upHint: vm.Vector3.zero()),
        ];
        for (final edit in invalid) {
          camera.viewProjectionMatrix;
          expect(edit, throwsArgumentError);
          expect(camera.worldPosition.storage, orderedEquals(position.storage));
          expect(camera.worldRotation.storage, orderedEquals(rotation.storage));
          expectMatrix(camera.viewMatrix, view);
        }
      });

      test(
        'camera and Transform share lookAt conventions without sharing state',
        () {
          final camera = create()..setPosition(3, 4, 12);
          final transform = Transform(position: camera.worldPosition)
            ..setScale(-2, 3, 4);
          final target = vm.Vector3(-2, 1, -5);
          final upHint = vm.Vector3(1, 2, 0);
          camera.lookAt(target, upHint: upHint);
          transform.lookAt(target, upHint: upHint);
          expect(
            camera.worldRotation.storage,
            orderedEquals(transform.rotation.storage),
          );
          expect(transform.scale.storage, orderedEquals([-2, 3, 4]));
          transform.setScale(1, 1, 1);
          expectMatrix(camera.worldMatrix, transform.matrix);
          transform.setPosition(7, 8, 9);
          expect(camera.worldPosition.storage, orderedEquals([3, 4, 12]));
        },
      );
    });
  }

  test('pose and view operations do not depend on projection availability', () {
    final camera = UnavailableProjectionCamera()..setPosition(3, 4, 12);
    camera.lookAt(vm.Vector3.zero());
    final position = camera.worldPosition;
    final rotation = camera.worldRotation;
    final world = camera.worldMatrix;
    final view = camera.viewMatrix;
    expect(() => camera.viewProjectionMatrix, throwsStateError);
    expect(camera.worldPosition.storage, orderedEquals(position.storage));
    expect(camera.worldRotation.storage, orderedEquals(rotation.storage));
    expectMatrix(camera.worldMatrix, world);
    expectMatrix(camera.viewMatrix, view);
    camera.setPosition(-1, 2, 3);
    camera.setRotation(vm.Quaternion.identity());
    expectMatrix(camera.viewMatrix, vm.Matrix4.translationValues(1, -2, -3));
  });
}
