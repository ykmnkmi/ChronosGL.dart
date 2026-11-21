@TestOn('chrome')
library;

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

// Regression coverage for world-space eye position and legacy view matrices.
const tolerance = 2e-5;

void expectVector(vm.Vector3 actual, vm.Vector3 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((v) => closeTo(v, tolerance))),
  );
}

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((v) => closeTo(v, tolerance))),
  );
}

vm.Matrix4 viewOf(Spatial camera) {
  final view = vm.Matrix4.zero();
  camera.getViewMatrix(view);
  return view;
}

// Legacy subclasses may provide an independent view and eye, as golden scenes do.
class CustomCamera extends Spatial {
  CustomCamera() : super('custom');

  final eye = vm.Vector3(6, -2, 9);

  @override
  vm.Vector3 getEyePosition() => eye;

  @override
  void getViewMatrix(vm.Matrix4 matrix) =>
      vm.setViewMatrix(matrix, eye, vm.Vector3.zero(), vm.Vector3(0, 1, 0));
}

void main() {
  test('lookAt preserves the world position and eye maps to view origin', () {
    final camera = Spatial('camera')..setPos(0, 0, 10);
    final before = vm.Vector3.copy(camera.getPos());
    camera.lookAt(vm.Vector3.zero());
    expect(camera.getPos().storage, orderedEquals([0, 0, 10]));
    expect(camera.getEyePosition().storage, orderedEquals([0, 0, 10]));
    expect(
      viewOf(camera).transformed3(before).storage,
      orderedEquals([0, 0, 0]),
    );
  });

  test('view is the inverse pose even before lookAt', () {
    final camera = Spatial('camera')
      ..setPos(3, -4, 12)
      ..rotY(0.7)
      ..rotX(-0.3);
    final pose = vm.Matrix4.copy(camera.transform);
    expectMatrix(viewOf(camera), vm.Matrix4.inverted(pose));
    expectVector(
      viewOf(camera).transformed3(camera.getEyePosition()),
      vm.Vector3.zero(),
    );
    expect(camera.transform.storage, orderedEquals(pose.storage));
  });

  test('repeated off-axis lookAt agrees with Camera and preserves inputs', () {
    final camera = Spatial('camera')..setPos(3, -4, 12);
    final modern = PerspectiveCamera(near: 0.1, far: 100)
      ..setPosition(3, -4, 12);
    final eye = vm.Vector3.copy(camera.getPos());
    final up = vm.Vector3(0.2, 1, 0.3);
    final savedUp = vm.Vector3.copy(up);
    for (final target in [
      vm.Vector3.zero(),
      vm.Vector3(-5, 7, 2),
      vm.Vector3(10, 1, 14),
    ]) {
      final savedTarget = vm.Vector3.copy(target);
      for (var i = 0; i < 3; i++) {
        camera.lookAt(target, up);
        modern.lookAt(target, upHint: up);
        expect(camera.getPos().storage, orderedEquals(eye.storage));
        expectVector(camera.getEyePosition(), eye);
        expectMatrix(camera.transform, modern.worldMatrix);
        expectMatrix(viewOf(camera), vm.makeViewMatrix(eye, target, up));
        expectVector(viewOf(camera).transformed3(eye), vm.Vector3.zero());
        expect(target.storage, orderedEquals(savedTarget.storage));
        expect(up.storage, orderedEquals(savedUp.storage));
      }
    }
  });

  test('movement uses world pose columns after lookAt', () {
    final camera = Spatial('camera')..setPos(2, 3, 4);
    camera.lookAt(vm.Vector3(7, 3, 4));
    expectVector(camera.getBack(), vm.Vector3(-1, 0, 0));
    expectVector(camera.getRight(), vm.Vector3(0, 0, 1));
    expectVector(camera.getUp(), vm.Vector3(0, 1, 0));
    camera.moveForward(2);
    expectVector(camera.getPos(), vm.Vector3(4, 3, 4));
    camera.moveRight(3);
    camera.moveUp(4);
    expectVector(camera.getPos(), vm.Vector3(4, 7, 7));
    camera.moveBackward(2);
    camera.moveLeft(3);
    camera.moveDown(4);
    expectVector(camera.getPos(), vm.Vector3(2, 3, 4));
    camera.addPos(5, -2, 1);
    camera.lookAt(vm.Vector3.zero());
    expectVector(camera.getEyePosition(), vm.Vector3(7, 1, 5));
    expectVector(
      viewOf(camera).transformed3(camera.getEyePosition()),
      vm.Vector3.zero(),
    );
  });

  test('look and roll helpers rotate local axes without moving the eye', () {
    final camera = Spatial('camera')..setPos(3, 4, 12);
    camera.lookAt(vm.Vector3(-2, 1, 0));
    final initial = vm.Matrix4.copy(camera.transform);
    camera.lookUp(0.3);
    expectMatrix(camera.transform, vm.Matrix4.copy(initial)..rotateX(0.3));
    camera.lookDown(0.3);
    camera.lookLeft(0.4);
    expectMatrix(camera.transform, vm.Matrix4.copy(initial)..rotateY(0.4));
    camera.lookRight(0.4);
    camera.rollLeft(0.5);
    expectMatrix(camera.transform, vm.Matrix4.copy(initial)..rotateZ(0.5));
    camera.rollRight(0.5);
    expectMatrix(camera.transform, initial);
    expectVector(camera.getEyePosition(), vm.Vector3(3, 4, 12));
    expectVector(
      viewOf(camera).transformed3(camera.getEyePosition()),
      vm.Vector3.zero(),
    );
  });

  test('invalid lookAt leaves the complete pose unchanged', () {
    final camera = Spatial('camera')
      ..setPos(0, 0, 10)
      ..rotY(0.4);
    final before = vm.Matrix4.copy(camera.transform);
    for (final operation in <void Function()>[
      () => camera.lookAt(camera.getPos()),
      () => camera.lookAt(vm.Vector3(double.nan, 0, 0)),
      () => camera.lookAt(vm.Vector3.zero(), vm.Vector3.zero()),
      () => camera.lookAt(vm.Vector3.zero(), vm.Vector3(0, 0, 1)),
      () => camera.lookAt(vm.Vector3.zero(), vm.Vector3(0, 1e-7, 1)),
      () => camera.lookAt(vm.Vector3.zero(), vm.Vector3(0, double.infinity, 0)),
    ]) {
      expect(operation, throwsArgumentError);
      expect(camera.transform.storage, orderedEquals(before.storage));
    }
  });

  test('failed view calculation preserves pose and caller output', () {
    final camera = Spatial('camera')..setPos(0, 0, 10);
    final output = vm.Matrix4.translationValues(4, 5, 6);
    final before = vm.Matrix4.copy(output);
    expect(() => camera.getViewMatrix(camera.transform), throwsArgumentError);
    expectVector(camera.getPos(), vm.Vector3(0, 0, 10));
    for (final invalid in [
      vm.Matrix4.zero(),
      vm.Matrix4.identity()..[0] = double.nan,
    ]) {
      camera.transform.setFrom(invalid);
      expect(() => camera.getViewMatrix(output), throwsStateError);
      expect(output.storage, orderedEquals(before.storage));
      for (var i = 0; i < 16; i++) {
        expect(camera.transform[i], invalid[i].isNaN ? isNaN : invalid[i]);
      }
    }
    camera.transform.setIdentity();
    camera.setPos(0, 0, 10);
    expectVector(
      viewOf(camera).transformed3(camera.getPos()),
      vm.Vector3.zero(),
    );
  });

  for (final orthographic in [false, true]) {
    final name = orthographic ? 'Orthographic' : 'Perspective';
    UniformGroup adapter(Spatial camera) => orthographic
        ? Orthographic(camera, -4, 4, -4, 0.1, 100)
        : Perspective(camera, 0.1, 100);
    vm.Matrix4 projection() => orthographic
        ? vm.makeOrthographicMatrix(-4, 4, -4, 4, 0.1, 100)
        : vm.makePerspectiveMatrix(50 * math.pi / 180, 1, 0.1, 100);

    test('$name publishes world eye and matching P * V after pose edits', () {
      final camera = Spatial('camera')..setPos(0, 0, 10);
      final uniforms = adapter(camera);
      for (final eye in [
        vm.Vector3(0, 0, 10),
        vm.Vector3(3, -4, 12),
        vm.Vector3(-7, 2, 5),
      ]) {
        camera.setPosFromVec(eye);
        for (final target in [vm.Vector3.zero(), vm.Vector3(1, -1, 2)]) {
          camera.lookAt(target);
          final values = uniforms.getUniforms();
          expectVector(values[uEyePosition]! as vm.Vector3, eye);
          final expected = projection()
            ..multiply(vm.makeViewMatrix(eye, target, vm.Vector3(0, 1, 0)));
          expectMatrix(values[uPerspectiveViewMatrix]! as vm.Matrix4, expected);
          expectVector(camera.getPos(), eye);
        }
      }
    });

    test('$name honors custom camera view and world eye overrides', () {
      final camera = CustomCamera();
      final values = adapter(camera).getUniforms();
      expectVector(values[uEyePosition]! as vm.Vector3, camera.eye);
      expectMatrix(
        values[uPerspectiveViewMatrix]! as vm.Matrix4,
        projection()..multiply(viewOf(camera)),
      );
    });
  }

  test('Perspective camera replacement refreshes eye and view together', () {
    final first = Spatial('first')
      ..setPos(0, 0, 10)
      ..lookAt(vm.Vector3.zero());
    final adapter = Perspective(first, 0.1, 100);
    adapter.getUniforms();
    final replacement = CustomCamera();
    adapter.updateCamera(replacement);
    final values = adapter.getUniforms();
    expectVector(values[uEyePosition]! as vm.Vector3, replacement.eye);
    expectMatrix(
      values[uPerspectiveViewMatrix]! as vm.Matrix4,
      vm.makePerspectiveMatrix(50 * math.pi / 180, 1, 0.1, 100)
        ..multiply(viewOf(replacement)),
    );
  });

  test(
    'OrbitCamera retains world eye across frames, target changes and roll',
    () {
      final camera = OrbitCamera(10, 0.7, 0.4, web.HTMLCanvasElement());
      addTearDown(camera.keyboard.dispose);
      addTearDown(camera.mouse.dispose);
      final adapter = Perspective(camera, 0.1, 100);
      for (final target in [vm.Vector3.zero(), vm.Vector3(2, -3, 4)]) {
        camera.setLookAt(target);
        final eye =
            target +
            vm.Vector3(
              10 * math.cos(0.4) * math.cos(0.7),
              10 * math.sin(0.4),
              10 * math.cos(0.4) * math.sin(0.7),
            );
        for (final roll in [0.0, 0.5, -0.3]) {
          camera.roll = roll;
          for (var frame = 0; frame < 3; frame++) {
            camera.animate(16);
            expectVector(camera.getPos(), eye);
            expectVector(camera.getEyePosition(), eye);
            expectVector(
              adapter.getUniforms()[uEyePosition]! as vm.Vector3,
              eye,
            );
            expectVector(
              viewOf(camera).transformed3(target),
              vm.Vector3(0, 0, -10),
            );
            expectVector(viewOf(camera).transformed3(eye), vm.Vector3.zero());
            final baseWorld = vm.Matrix4.inverted(
              vm.makeViewMatrix(eye, target, vm.Vector3(0, 1, 0)),
            )..rotateZ(roll);
            expectMatrix(camera.transform, baseWorld);
          }
        }
      }
    },
  );

  test('Node lookAt retains local position under a transformed parent', () {
    final parent = Node.container('parent')
      ..setPos(7, 2, -3)
      ..rotY(0.4);
    final node = Node.container('child')..setPos(2, 3, 4);
    final target = vm.Vector3(-5, 7, 1);
    node.lookAt(target);
    final pose = Transform()
      ..setPosition(2, 3, 4)
      ..lookAt(target);
    expectMatrix(node.transform, pose.matrix);
    expectMatrix(
      node.updateModelMatrix(parent.transform),
      vm.Matrix4.copy(parent.transform)..multiply(pose.matrix),
    );
    expectVector(node.getPos(), vm.Vector3(2, 3, 4));
  });
}
