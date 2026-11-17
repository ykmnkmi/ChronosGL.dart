import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chronosgl/camera.dart';
import 'package:chronosgl/core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((value) => closeTo(value, 2e-5))),
  );
}

List<vm.Matrix4> matrices(Camera camera) => [
  camera.worldMatrix,
  camera.viewMatrix,
  camera.projectionMatrix,
  camera.viewProjectionMatrix,
];

List<void Function(vm.Matrix4)> copiers(Camera camera) => [
  camera.copyWorldMatrixInto,
  camera.copyViewMatrixInto,
  camera.copyProjectionMatrixInto,
  camera.copyViewProjectionMatrixInto,
];

void changeProjection(Camera camera) {
  if (camera is PerspectiveCamera) {
    camera.setProjection(fovYRadians: 1.2, aspectRatio: 2, near: 2, far: 70);
  } else if (camera is OrthographicCamera) {
    camera.setProjection(
      left: -8,
      right: 4,
      bottom: -2,
      top: 6,
      near: -10,
      far: 70,
    );
  }
}

class UnavailableProjectionCamera extends Camera {
  @override
  vm.Matrix4 get projectionMatrix => throw StateError('Projection unavailable');
}

void main() {
  final factories = <String, Camera Function()>{
    'perspective': () => PerspectiveCamera(near: 1, far: 100),
    'orthographic': () => OrthographicCamera(
      left: -4,
      right: 4,
      bottom: -3,
      top: 3,
      near: 1,
      far: 100,
    ),
  };
  for (final entry in factories.entries) {
    group(entry.key, () {
      test('raw matrix storage cannot corrupt pose or a shared projection', () {
        final camera = entry.value()
          ..setPosition(3, -4, 12)
          ..lookAt(vm.Vector3(-2, 1, 0));
        final Camera peer;
        if (camera is PerspectiveCamera) {
          peer = PerspectiveCamera.fromProjection(camera.projection);
        } else {
          peer = OrthographicCamera.fromProjection(
            (camera as OrthographicCamera).projection,
          );
        }
        final expected = matrices(camera);
        final peerProjection = peer.projectionMatrix;
        final snapshots = matrices(camera);
        for (var i = 0; i < snapshots.length; i++) {
          // Exercise typed-data aliases, not only Matrix4's mutating methods.
          final storage = snapshots[i].storage;
          Float32List.view(
            storage.buffer,
            storage.offsetInBytes,
            16,
          ).fillRange(0, 16, double.nan);
          final current = matrices(camera);
          for (var j = 0; j < current.length; j++) {
            expectMatrix(current[j], expected[j]);
          }
          expectMatrix(peer.projectionMatrix, peerProjection);
        }
        expect(camera.worldPosition.storage, orderedEquals([3, -4, 12]));
        expectMatrix(
          camera.viewMatrix..multiply(camera.worldMatrix),
          vm.Matrix4.identity(),
        );
      });

      test(
        'all edits refresh matrices without updating retained snapshots',
        () {
          final camera = entry.value()..setPosition(0, 0, 10);
          final saved = matrices(camera);
          final savedValues = saved.map((m) => m.storage.toList()).toList();
          final changes = <void Function()>[
            () => camera.setPosition(3, -4, 12),
            () => camera.setRotation(
              vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0.7),
            ),
            () => changeProjection(camera),
            () => camera.setPositionFromVector(vm.Vector3(-2, 5, 7)),
            () => camera.lookAt(vm.Vector3(1, 0, -3)),
          ];
          for (final change in changes) {
            change();
            // Read the derived result first, without priming any other getter.
            final combined = camera.viewProjectionMatrix;
            final view = camera.viewMatrix;
            final world = camera.worldMatrix;
            expectMatrix(combined, camera.projectionMatrix..multiply(view));
            expectMatrix(view..multiply(world), vm.Matrix4.identity());
            expect(
              world.getTranslation().storage,
              orderedEquals(camera.worldPosition.storage),
            );
            for (var i = 0; i < saved.length; i++) {
              expect(saved[i].storage, orderedEquals(savedValues[i]));
            }
          }
        },
      );

      test(
        'copy destinations are reusable, independent and never retained',
        () {
          final camera = entry.value()
            ..setPosition(3, -4, 12)
            ..lookAt(vm.Vector3.zero());
          final copies = copiers(camera);
          // A subview also ensures the copy respects destination byte offsets.
          final storage = Float32List(24)..fillRange(0, 24, 123);
          final out = vm.Matrix4.fromBuffer(
            storage.buffer,
            4 * Float32List.bytesPerElement,
          );
          final initial = matrices(camera);
          final retained = <vm.Matrix4>[];
          for (var i = 0; i < copies.length; i++) {
            copies[i](out);
            expectMatrix(out, initial[i]);
            expect(storage.take(4), everyElement(123));
            expect(storage.skip(20), everyElement(123));
            final snapshot = vm.Matrix4.zero();
            copies[i](snapshot);
            retained.add(snapshot);
            out.storage.fillRange(0, 16, double.nan);
            expectMatrix(matrices(camera)[i], initial[i]);
          }
          camera.setPosition(-5, 6, 7);
          changeProjection(camera);
          final updated = matrices(camera);
          for (var i = 0; i < copies.length; i++) {
            expectMatrix(retained[i], initial[i]);
            copies[i](out);
            expectMatrix(out, updated[i]);
          }
        },
      );

      test(
        'view overflow preserves copy destinations and permits recovery',
        () {
          final camera = entry.value()
            ..setPosition(3e38, 3e38, 0)
            ..setRotation(
              vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 4),
            );
          final out = vm.Matrix4.translationValues(7, 8, 9);
          final before = vm.Matrix4.copy(out);
          final pose = camera.worldMatrix;
          for (final copy in [
            camera.copyViewMatrixInto,
            camera.copyViewProjectionMatrixInto,
          ]) {
            expect(() => copy(out), throwsStateError);
            expect(out.storage, orderedEquals(before.storage));
            expect(camera.worldMatrix.storage, orderedEquals(pose.storage));
          }
          camera.copyWorldMatrixInto(out);
          expect(out.storage, orderedEquals(pose.storage));
          camera.copyProjectionMatrixInto(out);
          expectMatrix(out, camera.projectionMatrix);
          camera.setPosition(1, 2, 3);
          camera.copyViewMatrixInto(out);
          expectMatrix(out, camera.viewMatrix);
          camera.copyViewProjectionMatrixInto(out);
          expectMatrix(
            out,
            camera.projectionMatrix..multiply(camera.viewMatrix),
          );
        },
      );
    });
  }

  test('combined-only overflow preserves output and recovers after projection edit', () {
    final camera = PerspectiveCamera(near: 1, far: 100, aspectRatio: 0.01)
      ..setPosition(1e38, 0, 0);
    final out = vm.Matrix4.translationValues(7, 8, 9);
    final before = vm.Matrix4.copy(out);
    expect(camera.viewMatrix.storage.every((value) => value.isFinite), isTrue);
    expect(() => camera.copyViewProjectionMatrixInto(out), throwsStateError);
    expect(out.storage, orderedEquals(before.storage));
    camera.setProjection(fovYRadians: 1.5, aspectRatio: 2, near: 1, far: 100);
    camera.copyViewProjectionMatrixInto(out);
    expect(out.storage, orderedEquals(camera.viewProjectionMatrix.storage));
  });

  test(
    'unavailable projection leaves outputs intact and pose copies usable',
    () {
      final camera = UnavailableProjectionCamera()..setPosition(1, 2, 3);
      final out = vm.Matrix4.translationValues(7, 8, 9);
      final before = vm.Matrix4.copy(out);
      for (final copy in [
        camera.copyProjectionMatrixInto,
        camera.copyViewProjectionMatrixInto,
      ]) {
        expect(() => copy(out), throwsStateError);
        expect(out.storage, orderedEquals(before.storage));
      }
      camera.copyWorldMatrixInto(out);
      expectMatrix(out, vm.Matrix4.translationValues(1, 2, 3));
      camera.copyViewMatrixInto(out);
      expectMatrix(out, vm.Matrix4.translationValues(-1, -2, -3));
    },
  );

  test(
    'Transform matrix edits require explicit commit and copy their input',
    () {
      final transform = Transform()..setPosition(1, 2, 3);
      final edit = transform.matrix;
      final alias = vm.Matrix4.fromBuffer(
        edit.storage.buffer,
        edit.storage.offsetInBytes,
      );
      alias.setTranslation(vm.Vector3(4, 5, 6));
      expect(transform.position.storage, orderedEquals([1, 2, 3]));
      transform.setMatrix(edit);
      alias.storage.fillRange(0, 16, double.nan);
      expect(transform.position.storage, orderedEquals([4, 5, 6]));
      final out = vm.Matrix4.zero();
      transform.copyMatrixInto(out);
      transform.setPosition(7, 8, 9);
      expect(out.getTranslation().storage, orderedEquals([4, 5, 6]));
      out.setZero();
      expect(transform.position.storage, orderedEquals([7, 8, 9]));
    },
  );
}
