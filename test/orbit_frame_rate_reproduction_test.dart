@TestOn('chrome')
library;

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

// Phase 1.9 reproductions are now regressions for Phase 4's seconds-based API.
typedef _OrbitState = ({
  double azimuth,
  double polar,
  double radius,
  vm.Vector3 eye,
});

web.KeyboardEvent _key(String type, int key) =>
    web.KeyboardEvent(type, web.KeyboardEventInit(which: key, keyCode: key));

_OrbitState _snapshot(OrbitControls controls) {
  final eye = vm.Matrix4.inverted(controls.camera.viewMatrix).getTranslation();
  return (
    azimuth: controls.azimuth,
    polar: controls.polar,
    radius: controls.radius,
    eye: eye,
  );
}

_OrbitState _simulate(
  OrbitControls controls,
  web.EventTarget target,
  int key,
  List<double> deltas,
) {
  controls
    ..azimuth = 0
    ..polar = 0
    ..radius = 10
    ..update(0);
  target.dispatchEvent(_key('keydown', key));
  late final _OrbitState result;
  try {
    for (final delta in deltas) {
      controls.update(delta);
    }
    result = _snapshot(controls);
  } finally {
    target.dispatchEvent(_key('keyup', key));
  }
  controls.update(1 / 60);
  final released = _snapshot(controls);
  expect(released.azimuth, result.azimuth);
  expect(released.polar, result.polar);
  expect(released.radius, result.radius);
  expect(released.eye.distanceTo(result.eye), lessThan(1e-5));
  return result;
}

void main() {
  late OrbitControls controls;
  late web.HTMLDivElement target;
  setUp(() {
    target = web.HTMLDivElement()
      ..style.width = '320px'
      ..style.height = '240px';
    web.document.body!.appendChild(target);
    addTearDown(() => target.remove());
    controls = OrbitControls(
      PerspectiveCamera(near: 0.1, far: 100),
      target,
      rotationSpeed: 1.8,
      zoomSpeed: 0.6,
    );
    addTearDown(controls.dispose);
  });

  for (final (key, label, horizontal, sign) in [
    (Keyboard.left, 'left', true, 1),
    (Keyboard.right, 'right', true, -1),
    (Keyboard.up, 'up', false, 1),
    (Keyboard.down, 'down', false, -1),
  ]) {
    test(
      '$label rotation matches for equal time at 30, 60, 120 and irregular FPS',
      () {
        final schedules = [
          for (final fps in [30, 60, 120])
            List<double>.filled(fps ~/ 5, 1 / fps),
          [0.001, 0.019, 0.07, 0.0, 0.11],
        ];
        vm.Vector3? firstEye;
        for (final deltas in schedules) {
          expect(deltas.reduce((a, b) => a + b), closeTo(0.2, 1e-12));
          final state = _simulate(controls, target, key, deltas);
          expect(
            horizontal ? state.azimuth : state.polar,
            closeTo(sign * 0.36, 1e-12),
          );
          expect(horizontal ? state.polar : state.azimuth, 0);
          expect(state.eye.length, closeTo(10, 1e-5));
          expect(state.polar.abs(), lessThan(math.pi / 2 - 0.1));
          final expectedEye = vm.Vector3(
            10 * math.cos(state.polar) * math.cos(state.azimuth),
            10 * math.sin(state.polar),
            10 * math.cos(state.polar) * math.sin(state.azimuth),
          );
          expect(state.eye.distanceTo(expectedEye), lessThan(1e-5));
          firstEye ??= state.eye;
          expect(state.eye.distanceTo(firstEye), lessThan(1e-5));
        }
      },
    );
  }

  for (final (key, label, sign) in [
    (Keyboard.pageUp, 'PageUp', -1),
    (Keyboard.pageDown, 'PageDown', 1),
  ]) {
    test(
      '$label zoom matches for equal time at 30, 60, 120 and irregular FPS',
      () {
        final schedules = [
          for (final fps in [30, 60, 120]) List<double>.filled(fps, 1 / fps),
          [0.13, 0.0, 0.02, 0.35, 0.5],
        ];
        for (final deltas in schedules) {
          expect(deltas.reduce((a, b) => a + b), closeTo(1, 1e-12));
          final state = _simulate(controls, target, key, deltas);
          expect(state.azimuth, 0);
          expect(state.polar, 0);
          expect(state.radius, closeTo(10 * math.exp(sign * 0.6), 1e-10));
          expect(state.eye.length, closeTo(state.radius, 1e-5));
        }
      },
    );
  }

  test('held rotation and zoom keys do not move with zero elapsed time', () {
    for (final key in [
      Keyboard.left,
      Keyboard.up,
      Keyboard.pageUp,
      Keyboard.pageDown,
    ]) {
      final state = _simulate(
        controls,
        target,
        key,
        List<double>.filled(10, 0),
      );
      expect(state.azimuth, 0);
      expect(state.polar, 0);
      expect(state.radius, 10);
      expect(state.eye.distanceTo(vm.Vector3(10, 0, 0)), lessThan(1e-5));
    }
  });
}
