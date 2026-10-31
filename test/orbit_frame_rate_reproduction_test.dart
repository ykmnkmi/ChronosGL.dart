@TestOn('chrome')
library;

import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

// Characterize the known frame-rate bug, not the desired controls contract.
// In phase 4 (4.3, 4.10), compare equal results for equal simulated durations
// using update(deltaSeconds). See docs/1.9_SHARED_SETTINGS_AND_FRAME_RATE_REPRODUCTIONS.md.
typedef _OrbitState = ({double azimuth, double polar, vm.Vector3 eye});

web.KeyboardEvent _key(String type, int key) =>
    web.KeyboardEvent(type, web.KeyboardEventInit(which: key, keyCode: key));

_OrbitState _snapshot(OrbitCamera camera) {
  final view = vm.Matrix4.zero();
  camera.getViewMatrix(view);
  // getPos() currently returns view translation (see reproduction 1.5).
  // Recover the actual world-space eye from the valid view matrix instead.
  final eye = vm.Matrix4.inverted(view).getTranslation();
  return (azimuth: camera.azimuth, polar: camera.polar, eye: eye);
}

_OrbitState _simulate(OrbitCamera camera, int key, List<double> deltasMs) {
  camera
    ..azimuth = 0
    ..polar = 0
    ..setRadius(10)
    ..animate(0);
  expect(camera.keyboard.currentlyPressedKey(key), isFalse);
  web.document.dispatchEvent(_key('keydown', key));
  late final _OrbitState result;
  try {
    expect(camera.keyboard.currentlyPressedKey(key), isTrue);
    for (final deltaMs in deltasMs) {
      camera.animate(deltaMs);
    }
    expect(camera.keyboard.currentlyPressedKey(key), isTrue);
    result = _snapshot(camera);
  } finally {
    web.document.dispatchEvent(_key('keyup', key));
    camera.keyboard.afterFrameCleanup();
  }
  // Releasing the key stops movement, independently of the reproduced bug.
  camera.animate(1000 / 60);
  final released = _snapshot(camera);
  expect(camera.keyboard.currentlyPressedKey(key), isFalse);
  expect(released.azimuth, result.azimuth);
  expect(released.polar, result.polar);
  expect(released.eye.distanceTo(result.eye), lessThan(1e-5));
  return result;
}

void main() {
  late OrbitCamera camera;
  setUpAll(() {
    // Reuse one camera: the current API cannot dispose its document listeners.
    // The browser test environment owns their lifetime; keyup runs in finally.
    camera = OrbitCamera(10, 0, 0, web.HTMLCanvasElement());
  });

  for (final (key, label, horizontal, sign) in [
    (Keyboard.left, 'left', true, 1),
    (Keyboard.right, 'right', true, -1),
    (Keyboard.up, 'up', false, 1),
    (Keyboard.down, 'down', false, -1),
  ]) {
    test(
      'Known bug: $label rotation depends on frames over the same 200 ms',
      () {
        final angles = <double>[];
        for (final fps in [30, 60, 120]) {
          final deltas = List<double>.filled(fps ~/ 5, 1000 / fps);
          expect(deltas.reduce((a, b) => a + b), closeTo(200, 1e-8));
          final state = _simulate(camera, key, deltas);
          final angle = horizontal ? state.azimuth : state.polar;
          angles.add(angle);
          expect(angle, closeTo(sign * 0.03 * deltas.length, 1e-8));
          expect(horizontal ? state.polar : state.azimuth, 0);
          expect(state.eye.length, closeTo(10, 1e-5));
          // Keep the polar angle below its clamp, so saturation cannot mask drift.
          expect(state.polar.abs(), lessThan(math.pi / 2 - 0.1));
          final expectedEye = vm.Vector3(
            10 * math.cos(state.polar) * math.cos(state.azimuth),
            10 * math.sin(state.polar),
            10 * math.cos(state.polar) * math.sin(state.azimuth),
          );
          expect(state.eye.distanceTo(expectedEye), lessThan(1e-5));
        }
        expect(angles[1], closeTo(angles[0] * 2, 1e-8));
        expect(angles[2], closeTo(angles[0] * 4, 1e-8));
      },
    );
  }

  for (final (key, label, factor) in [
    (Keyboard.pageUp, 'PageUp', 0.99),
    (Keyboard.pageDown, 'PageDown', 1.01),
  ]) {
    test('Known bug: $label zoom depends on frames over the same second', () {
      final radii = <double>[];
      for (final fps in [30, 60, 120]) {
        final deltas = List<double>.filled(fps, 1000 / fps);
        expect(deltas.reduce((a, b) => a + b), closeTo(1000, 1e-8));
        final state = _simulate(camera, key, deltas);
        expect(state.azimuth, 0);
        expect(state.polar, 0);
        final radius = state.eye.length;
        radii.add(radius);
        expect(radius, closeTo(10 * math.pow(factor, fps), 1e-5));
      }
      expect((radii[0] - radii[1]).abs(), greaterThan(1));
      expect((radii[1] - radii[2]).abs(), greaterThan(1));
    });
  }

  test(
    'Known bug: held key rotates the camera even with zero elapsed time',
    () {
      final state = _simulate(
        camera,
        Keyboard.left,
        List<double>.filled(10, 0),
      );
      expect(state.azimuth, closeTo(0.3, 1e-8));
      expect(state.eye.distanceTo(vm.Vector3(10, 0, 0)), greaterThan(1));
    },
  );
}
