import 'dart:math' as math;

import 'package:chronosgl/core.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

const tolerance = 1e-5;

void expectVector(vm.Vector3 actual, List<double> expected) {
  expect(
    actual.storage,
    orderedEquals(expected.map((v) => closeTo(v, tolerance))),
  );
}

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((v) => closeTo(v, tolerance))),
  );
}

void main() {
  test('identity maps local coordinates to parent coordinates', () {
    final transform = Transform();
    expect(transform.hasTRS, isTrue);
    expectMatrix(transform.matrix, vm.Matrix4.identity());
    expectVector(transform.position, [0, 0, 0]);
    expectVector(transform.scale, [1, 1, 1]);
    expectVector(transform.right, [1, 0, 0]);
    expectVector(transform.up, [0, 1, 0]);
    expectVector(transform.back, [0, 0, 1]);
    expectVector(transform.forward, [0, 0, -1]);
  });

  test('TRS applies scale then right-handed rotation then translation', () {
    final transform = Transform(
      position: vm.Vector3(4, 5, 6),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
      scale: vm.Vector3(2, 3, 4),
    );
    expectVector(transform.matrix.transformed3(vm.Vector3(1, 0, 0)), [4, 7, 6]);
    expectVector(transform.matrix.transformed3(vm.Vector3(0, 1, 0)), [1, 5, 6]);
    expectVector(transform.matrix.transformed3(vm.Vector3(0, 0, 1)), [
      4,
      5,
      10,
    ]);
    expectVector(transform.right, [0, 1, 0]);
    expectVector(transform.up, [-1, 0, 0]);
  });

  test('input components and snapshots never alias transform state', () {
    final position = vm.Vector3(1, 2, 3);
    final rotation = vm.Quaternion(0, 0, 0, 2);
    final scale = vm.Vector3(2, 3, 4);
    final transform = Transform(
      position: position,
      rotation: rotation,
      scale: scale,
    );
    final before = transform.matrix;
    expect(transform.rotation.length, closeTo(1, tolerance));
    expect(rotation.w, 2); // Normalization must not mutate the caller.
    position.setZero();
    rotation.setValues(1, 0, 0, 0);
    scale.setZero();
    transform.position.setZero();
    transform.rotation.setValues(1, 0, 0, 0);
    transform.scale.setZero();
    transform.right.setZero();
    transform.up.setZero();
    transform.back.setZero();
    transform.forward.setZero();
    transform.matrix.setZero();
    expectMatrix(transform.matrix, before);
    final savedPosition = transform.position;
    final out = vm.Matrix4.zero();
    transform.copyMatrixInto(out);
    expectMatrix(out, before);
    transform.translate(3, 0, 0);
    expectVector(savedPosition, [1, 2, 3]);
    expectMatrix(out, before);
    out.setZero();
    expectVector(transform.position, [4, 2, 3]);
  });

  test(
    'parent and local translation have explicit scale-independent meanings',
    () {
      final transform = Transform(
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2),
        scale: vm.Vector3(-5, 0, 20),
      );
      transform.translate(0, 0, -2);
      expectVector(transform.position, [0, 0, -2]);
      transform.translateLocal(0, 0, -3);
      expectVector(transform.position, [-3, 0, -2]);
      expectVector(transform.forward, [-1, 0, 0]);
      expectVector(transform.scale, [-5, 0, 20]);
    },
  );

  test('local and parent rotations use opposite multiplication orders', () {
    Transform initial() => Transform(
      position: vm.Vector3(3, 4, 5),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
      scale: vm.Vector3(2, -3, 4),
    );
    final local = initial()..rotateLocal(vm.Vector3(10, 0, 0), math.pi / 2);
    final parent = initial()..rotateParent(vm.Vector3(10, 0, 0), math.pi / 2);
    expectVector(local.back, [1, 0, 0]);
    expectVector(parent.back, [0, -1, 0]);
    for (final transform in [local, parent]) {
      expectVector(transform.position, [3, 4, 5]);
      expectVector(transform.scale, [2, -3, 4]);
    }
  });

  test('component setters preserve the other components', () {
    final transform = Transform()..setPosition(3, 4, 5);
    transform.setScale(2, 3, -4);
    final rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi / 2);
    transform.setRotation(rotation);
    rotation.setValues(0, 0, 0, 1);
    expectVector(transform.position, [3, 4, 5]);
    expectVector(transform.scale, [2, 3, -4]);
    expectVector(transform.forward, [-1, 0, 0]);
    final p = vm.Vector3(6, 7, 8);
    transform.setPositionFromVector(p);
    p.setZero();
    expectVector(transform.matrix.transformed3(vm.Vector3(0, 0, -1)), [
      10,
      7,
      8,
    ]);
  });

  test('repeated orientation edits retain a normalized rotation', () {
    final transform = Transform();
    for (var i = 0; i < 1000; i++) {
      transform.rotateLocal(vm.Vector3(1, 2, 3), 0.001);
    }
    expect(transform.rotation.length, closeTo(1, tolerance));
    expect(transform.right.length, closeTo(1, tolerance));
    expect(transform.right.dot(transform.up), closeTo(0, tolerance));
    final inverse = vm.Matrix4.copy(transform.matrix)..invert();
    expectMatrix(inverse..multiply(transform.matrix), vm.Matrix4.identity());
  });

  test('lookAt preserves position and scale while orienting local -Z', () {
    final transform = Transform()
      ..setPosition(0, 0, 10)
      ..setScale(2, 3, 4);
    transform.lookAt(vm.Vector3.zero());
    expectVector(transform.position, [0, 0, 10]);
    expectVector(transform.forward, [0, 0, -1]);
    expectVector(transform.scale, [2, 3, 4]);
    expectVector(transform.matrix.transformed3(vm.Vector3.zero()), [0, 0, 10]);
    // This is an object transform; its translation is not a camera view offset.
    transform.lookAt(vm.Vector3(10, 0, 10), upHint: vm.Vector3(0, 5, 0));
    expectVector(transform.forward, [1, 0, 0]);
    expectVector(transform.up, [0, 1, 0]);
    expectVector(transform.right, [0, 0, 1]);
    expectVector(transform.position, [0, 0, 10]);
    expectVector(transform.scale, [2, 3, 4]);
  });

  test('lookAt accepts oblique targets and nonorthogonal up hints', () {
    final target = vm.Vector3(5, 7, -2);
    final hint = vm.Vector3(0, 3, 1);
    final transform = Transform(position: vm.Vector3(1, 2, 3));
    transform.lookAt(target, upHint: hint);
    final expectedForward = (target - transform.position)..normalize();
    expectVector(transform.forward, expectedForward.storage);
    expect(transform.forward.dot(transform.up), closeTo(0, tolerance));
    expect(transform.up.dot(hint), greaterThan(0));
    expectVector(transform.right.cross(transform.up), transform.back.storage);
    expectVector(target, [5, 7, -2]);
    expectVector(hint, [0, 3, 1]);
  });

  test('invalid lookAt arguments leave the complete state unchanged', () {
    final transform = Transform(
      position: vm.Vector3(0, 0, 10),
      scale: vm.Vector3(2, 3, 4),
    );
    final before = transform.matrix;
    final calls = <void Function()>[
      () => transform.lookAt(transform.position),
      () => transform.lookAt(vm.Vector3.zero(), upHint: vm.Vector3.zero()),
      () => transform.lookAt(vm.Vector3.zero(), upHint: vm.Vector3(0, 0, 1)),
      () => transform.lookAt(vm.Vector3.zero(), upHint: vm.Vector3(0, 0, -1)),
      () => transform.lookAt(vm.Vector3.zero(), upHint: vm.Vector3(0, 1e-7, 1)),
      () => transform.lookAt(vm.Vector3(double.nan, 0, 0)),
      () => transform.lookAt(
        vm.Vector3.zero(),
        upHint: vm.Vector3(0, double.infinity, 0),
      ),
    ];
    for (final call in calls) {
      expect(call, throwsArgumentError);
      expectMatrix(transform.matrix, before);
      expect(transform.hasTRS, isTrue);
    }
    transform.lookAt(vm.Vector3.zero(), upHint: vm.Vector3(0, 1e-4, 1));
    expectVector(transform.forward, [0, 0, -1]);
  });

  test('world composition depends on the supplied parent path', () {
    final child = Transform(position: vm.Vector3(1, 0, 0));
    final parentA = Transform(position: vm.Vector3(10, 0, 0));
    final parentB = Transform(
      position: vm.Vector3(0, 5, 0),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
    );
    expectVector(
      (parentA.matrix..multiply(child.matrix)).transformed3(vm.Vector3.zero()),
      [11, 0, 0],
    );
    expectVector(
      (parentB.matrix..multiply(child.matrix)).transformed3(vm.Vector3.zero()),
      [0, 6, 0],
    );
    expectVector(child.position, [1, 0, 0]);
  });

  test('matrix imports copy input and preserve nonuniform reflected TRS', () {
    final original = Transform(
      position: vm.Vector3(7, 8, 9),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 2, 3)..normalize(), 0.7),
      scale: vm.Vector3(2, -3, 4),
    );
    final input = original.matrix;
    final transform = Transform.fromMatrix(input);
    input.setZero();
    expectMatrix(transform.matrix, original.matrix);
    expect(transform.hasTRS, isTrue);
    expectVector(transform.scale, [-2, 3, 4]);
    transform.setRotation(transform.rotation);
    expectMatrix(transform.matrix, original.matrix);
    transform.setScale(4, 5, 6);
    expectVector(transform.position, [7, 8, 9]);
  });

  test('shear stays exact and component edits reject lossy decomposition', () {
    final input = vm.Matrix4.identity()..setEntry(0, 1, 0.5);
    final transform = Transform.fromMatrix(input);
    final before = transform.matrix;
    expect(transform.hasTRS, isFalse);
    final calls = <void Function()>[
      () {
        transform.rotation;
      },
      () {
        transform.scale;
      },
      () {
        transform.forward;
      },
      () => transform.setRotation(vm.Quaternion.identity()),
      () => transform.setScale(1, 1, 1),
      () => transform.rotateLocal(vm.Vector3(1, 0, 0), 0.2),
      () => transform.rotateParent(vm.Vector3(1, 0, 0), 0.2),
      () => transform.translateLocal(1, 2, 3),
      () => transform.lookAt(vm.Vector3(0, 0, -10)),
    ];
    for (final call in calls) {
      expect(call, throwsStateError);
      expectMatrix(transform.matrix, before);
    }
    transform.translate(1, 2, 3);
    expectVector(transform.matrix.transformed3(vm.Vector3(0, 2, 0)), [2, 4, 3]);
    transform.setPosition(4, 5, 6);
    expect(transform.matrix[4], 0.5);
    final edited = transform.matrix..setEntry(0, 1, 0.75);
    transform.setMatrix(edited);
    edited.setZero();
    expect(transform.matrix[4], 0.75);
    transform.setTRS(
      position: transform.position,
      rotation: vm.Quaternion.identity(),
      scale: vm.Vector3.all(1),
    );
    expect(transform.hasTRS, isTrue);
    expectVector(transform.position, [4, 5, 6]);
    expect(transform.matrix[4], 0);
  });

  test(
    'shear detection is independent of translation and other scale axes',
    () {
      final matrix = vm.Matrix4.identity()
        ..setEntry(0, 0, 1e10)
        ..setEntry(0, 1, 5e-11)
        ..setEntry(1, 1, 1e-10)
        ..setTranslation(vm.Vector3(1e20, 1e20, 1e20));
      final transform = Transform.fromMatrix(matrix);
      expect(transform.hasTRS, isFalse);
      expect(transform.matrix.storage, orderedEquals(matrix.storage));
    },
  );

  test(
    'composition can create shear and is never implicitly reduced to TRS',
    () {
      final parent = Transform(scale: vm.Vector3(2, 1, 1));
      final child = Transform(
        rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 4),
      );
      final product = parent.matrix..multiply(child.matrix);
      final transform = Transform.fromMatrix(product);
      expect(transform.hasTRS, isFalse);
      expect(transform.matrix.storage, orderedEquals(product.storage));
    },
  );

  test(
    'explicit zero scale keeps orientation; singular import keeps matrix',
    () {
      final transform = Transform(scale: vm.Vector3(0, 2, -3));
      transform.rotateLocal(vm.Vector3(0, 1, 0), math.pi / 2);
      transform.lookAt(vm.Vector3(1, 0, 0));
      expect(transform.hasTRS, isTrue);
      expectVector(transform.scale, [0, 2, -3]);
      expectVector(transform.forward, [1, 0, 0]);
      final imported = Transform.fromMatrix(transform.matrix);
      expect(imported.hasTRS, isFalse);
      expectMatrix(imported.matrix, transform.matrix);
      imported.translate(1, 2, 3);
      expectVector(imported.position, [1, 2, 3]);
      expect(() => imported.setScale(1, 1, 1), throwsStateError);
      transform.setScale(1, 2, 3);
      expectVector(transform.forward, [1, 0, 0]);
    },
  );

  test(
    'nonfinite, zero rotation/axis and projective inputs fail atomically',
    () {
      final transform = Transform(position: vm.Vector3(1, 2, 3));
      final before = transform.matrix;
      final perspective = vm.makePerspectiveMatrix(math.pi / 2, 1, 0.1, 100);
      final calls = <void Function()>[
        () => transform.setPosition(double.nan, 0, 0),
        () => transform.setPosition(1e100, 0, 0),
        () => transform.setScale(1, double.infinity, 1),
        () => transform.setRotation(vm.Quaternion(0, 0, 0, 0)),
        () => transform.setRotation(vm.Quaternion(0, double.nan, 0, 1)),
        () => transform.translate(0, 0, double.infinity),
        () => transform.translateLocal(1e100, 0, 0),
        () => transform.rotateLocal(vm.Vector3.zero(), 1),
        () => transform.rotateParent(vm.Vector3(1, 0, 0), double.nan),
        () => transform.setMatrix(perspective),
        () => transform.setMatrix(vm.Matrix4.identity()..setEntry(3, 3, 2)),
        () => transform.setMatrix(
          vm.Matrix4.identity()..setEntry(0, 0, double.infinity),
        ),
        () => transform.setTRS(
          position: vm.Vector3(9, 8, 7),
          rotation: vm.Quaternion(0, 0, 0, 0),
          scale: vm.Vector3.all(1),
        ),
      ];
      for (final call in calls) {
        expect(call, throwsArgumentError);
        expectMatrix(transform.matrix, before);
        expect(transform.hasTRS, isTrue);
      }
      expect(() => Transform.fromMatrix(perspective), throwsArgumentError);
      expect(
        () => Transform(scale: vm.Vector3(1, double.nan, 1)),
        throwsArgumentError,
      );
    },
  );
}
