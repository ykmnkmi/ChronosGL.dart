@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

// Legacy subclasses may place their pose inside a larger typed-data allocation.
class BufferedSpatial extends Spatial {
  BufferedSpatial(Float32List storage)
    : _bufferedTransform = vm.Matrix4.fromBuffer(storage.buffer, 16),
      super('buffered') {
    transform.setIdentity();
  }

  final vm.Matrix4 _bufferedTransform;

  @override
  vm.Matrix4 get transform => _bufferedTransform;
}

void main() {
  test('view output rejects distinct matrices aliasing the pose storage', () {
    final camera = Spatial('camera')..setPos(3, -4, 12);
    final pose = vm.Matrix4.copy(camera.transform);
    for (final out in [
      camera.transform,
      vm.Matrix4.fromFloat32List(camera.transform.storage),
      vm.Matrix4.fromBuffer(camera.transform.storage.buffer, 0),
    ]) {
      expect(() => camera.getViewMatrix(out), throwsArgumentError);
      expect(camera.transform.storage, orderedEquals(pose.storage));
    }
    final out = vm.Matrix4.zero();
    camera.getViewMatrix(out);
    expect(out.storage, orderedEquals(vm.Matrix4.inverted(pose).storage));
  });

  test(
    'view output rejects partial overlap but allows disjoint buffer views',
    () {
      final storage = Float32List(40);
      final camera = BufferedSpatial(storage)..setPos(3, -4, 12);
      final before = storage.toList();
      for (final offset in [0, 8, 20, 76]) {
        final out = vm.Matrix4.fromBuffer(storage.buffer, offset);
        expect(() => camera.getViewMatrix(out), throwsArgumentError);
        expect(storage, orderedEquals(before));
      }
      final disjoint = vm.Matrix4.fromBuffer(storage.buffer, 80);
      camera.getViewMatrix(disjoint);
      expect(
        disjoint.storage,
        orderedEquals(vm.Matrix4.translationValues(-3, 4, -12).storage),
      );
      expect(camera.getPos().storage, orderedEquals([3, -4, 12]));
    },
  );

  test(
    'camera matrix copies bridge to legacy pose without retaining storage',
    () {
      final Camera camera = PerspectiveCamera(near: 1, far: 100)
        ..setPosition(3, -4, 12)
        ..lookAt(vm.Vector3.zero());
      final legacy = Spatial('camera');
      camera.copyWorldMatrixInto(legacy.transform);
      final view = vm.Matrix4.zero();
      legacy.getViewMatrix(view);
      expect(view.storage, orderedEquals(camera.viewMatrix.storage));
      legacy.transform.setZero();
      expect(camera.worldPosition.storage, orderedEquals([3, -4, 12]));
      camera.copyWorldMatrixInto(legacy.transform);
      camera.setPosition(1, 2, 3);
      expect(legacy.getPos().storage, orderedEquals([3, -4, 12]));
    },
  );
}
