@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

web.KeyboardEvent _key(String type, String code) => web.KeyboardEvent(
  type,
  web.KeyboardEventInit(code: code, cancelable: true),
);

web.MouseEvent _mouse(String type, int x, int y) => web.MouseEvent(
  type,
  web.MouseEventInit(
    clientX: x,
    clientY: y,
    movementX: 999,
    movementY: -999,
    cancelable: true,
  ),
);

web.WheelEvent _wheel(double delta, {int mode = 0}) => web.WheelEvent(
  'wheel',
  web.WheelEventInit(deltaY: delta, deltaMode: mode, cancelable: true),
);

void _expectPose(Camera camera, vm.Matrix4 expected) {
  final actual = camera.worldMatrix;
  for (var i = 0; i < 16; i++) {
    expect(actual.storage[i], closeTo(expected.storage[i], 1e-5));
  }
}

class _Probe {
  _Probe(this.target) {
    final add = target.getProperty<JSFunction>('addEventListener'.toJS);
    final remove = target.getProperty<JSFunction>('removeEventListener'.toJS);
    target.setProperty(
      'addEventListener'.toJS,
      ((JSString type, JSFunction callback, [JSAny? options]) {
        added.add((type: type.toDart, callback: callback));
        add.callAsFunction(target, type, callback, options);
      }).toJS,
    );
    target.setProperty(
      'removeEventListener'.toJS,
      ((JSString type, JSFunction callback, [JSAny? options]) {
        removed.add((type: type.toDart, callback: callback));
        remove.callAsFunction(target, type, callback, options);
      }).toJS,
    );
    addTearDown(() {
      target.delete('addEventListener'.toJS);
      target.delete('removeEventListener'.toJS);
    });
  }

  final web.HTMLDivElement target;
  final List<({String type, JSFunction callback})> added = [];
  final List<({String type, JSFunction callback})> removed = [];
}

void main() {
  late web.HTMLDivElement target;
  late PerspectiveCamera camera;
  late OrbitControls controls;
  setUp(() {
    target = web.HTMLDivElement()
      ..style.width = '320px'
      ..style.height = '240px';
    web.document.body!.appendChild(target);
    addTearDown(() => target.remove());
    camera = PerspectiveCamera(near: 0.1, far: 100);
    controls = OrbitControls(camera, target);
    addTearDown(controls.dispose);
    controls.update(0);
  });

  test('copied target and orbit pose apply to both camera types', () {
    final supplied = vm.Vector3(2, -3, 4);
    controls
      ..target = supplied
      ..radius = 7
      ..azimuth = math.pi / 2
      ..polar = 0.3;
    supplied.setZero();
    controls.target.setZero();
    controls.update(0);
    final expected = vm.Vector3(
      2,
      -3 + 7 * math.sin(0.3),
      4 + 7 * math.cos(0.3),
    );
    expect(camera.worldPosition.distanceTo(expected), lessThan(1e-5));
    final inView = camera.viewMatrix.transform3(controls.target);
    expect(inView.x, closeTo(0, 1e-5));
    expect(inView.y, closeTo(0, 1e-5));
    expect(inView.z, closeTo(-7, 1e-5));
    expect(camera.near, 0.1);
    expect(camera.far, 100);
    final otherCamera = OrthographicCamera(
      left: -2,
      right: 2,
      bottom: -1,
      top: 1,
      near: 0,
      far: 100,
    );
    final other = OrbitControls(otherCamera, target, radius: 5, polar: -0.2);
    addTearDown(other.dispose);
    other.update(0);
    expect(otherCamera.worldPosition.length, closeTo(5, 1e-5));
    expect(
      otherCamera.viewMatrix.transform3(vm.Vector3.zero()).z,
      closeTo(-5, 1e-5),
    );
  });

  test('keyboard targets are isolated and opposing keys cancel', () {
    web.document.dispatchEvent(_key('keydown', 'ArrowLeft'));
    controls.update(0.2);
    expect(controls.azimuth, 0);
    final key = _key('keydown', 'ArrowLeft');
    target.dispatchEvent(key);
    expect(key.defaultPrevented, isTrue);
    controls.update(0.2);
    expect(controls.azimuth, closeTo(0.36, 1e-12));
    target.dispatchEvent(_key('keydown', 'ArrowRight'));
    controls.update(0.2);
    expect(controls.azimuth, closeTo(0.36, 1e-12));
    final unrelated = _key('keydown', 'KeyA');
    target.dispatchEvent(unrelated);
    expect(unrelated.defaultPrevented, isFalse);
  });

  test(
    'drag accumulates CSS differences and complete gestures consume once',
    () {
      target.dispatchEvent(_mouse('mousemove', 90, 90));
      target.dispatchEvent(_mouse('mousedown', 10, 20));
      target.dispatchEvent(_mouse('mousemove', 13, 25));
      target.dispatchEvent(_mouse('mousemove', 20, 30));
      target.dispatchEvent(_mouse('mouseup', 20, 30));
      target.dispatchEvent(_mouse('mousemove', 100, 100));
      controls.update(0);
      expect(controls.azimuth, closeTo(0.1, 1e-12));
      expect(controls.polar, closeTo(0.1, 1e-12));
      final pose = camera.worldMatrix;
      controls.update(10);
      _expectPose(camera, pose);
    },
  );

  test('mouse totals are independent of update frequency and time step', () {
    final primaryDown = _mouse('mousedown', 0, 0);
    target.dispatchEvent(primaryDown);
    expect(primaryDown.defaultPrevented, isFalse);
    target.dispatchEvent(_mouse('mousemove', 5, 5));
    target.dispatchEvent(_wheel(20));
    controls.update(0.01);
    target.dispatchEvent(_mouse('mousemove', 12, 9));
    target.dispatchEvent(_wheel(-5));
    controls.update(0.3);
    final pose = camera.worldMatrix;
    controls
      ..disable()
      ..azimuth = 0
      ..polar = 0
      ..radius = 10
      ..enable();
    target.dispatchEvent(_mouse('mousedown', 0, 0));
    target.dispatchEvent(_mouse('mousemove', 5, 5));
    target.dispatchEvent(_wheel(20));
    target.dispatchEvent(_mouse('mousemove', 12, 9));
    target.dispatchEvent(_wheel(-5));
    controls.update(0);
    _expectPose(camera, pose);
    expect(controls.radius, closeTo(10 * math.exp(15 * 0.002), 1e-10));
  });

  test('wheel fractions, lines and pages normalize and consume once', () {
    target.dispatchEvent(_wheel(0.5));
    target.dispatchEvent(_wheel(2, mode: 1));
    target.dispatchEvent(_wheel(-0.25, mode: 2));
    controls.update(0);
    expect(
      controls.radius,
      closeTo(10 * math.exp((0.5 + 32 - 60) * 0.002), 1e-10),
    );
    final radius = controls.radius;
    controls.update(0);
    expect(controls.radius, radius);
  });

  test('disabled input allows DOM defaults and never replays stale state', () {
    target.dispatchEvent(_key('keydown', 'ArrowLeft'));
    target.dispatchEvent(_mouse('mousedown', 0, 0));
    target.dispatchEvent(_mouse('mousemove', 10, 15));
    target.dispatchEvent(_wheel(50));
    final pose = camera.worldMatrix;
    controls.disable();
    for (final event in <web.Event>[
      _key('keydown', 'ArrowUp'),
      _mouse('mousedown', 0, 0),
      _wheel(10),
    ]) {
      target.dispatchEvent(event);
      expect(event.defaultPrevented, isFalse);
    }
    controls.update(1);
    _expectPose(camera, pose);
    controls.enable();
    controls.update(1);
    _expectPose(camera, pose);
  });

  for (final windowBlur in [false, true]) {
    test(
      '${windowBlur ? 'window' : 'target'} blur clears held and pending input',
      () {
        target.dispatchEvent(_key('keydown', 'ArrowLeft'));
        target.dispatchEvent(_mouse('mousedown', 0, 0));
        target.dispatchEvent(_mouse('mousemove', 10, 15));
        target.dispatchEvent(_wheel(50));
        final pose = camera.worldMatrix;
        (windowBlur ? web.window : target).dispatchEvent(web.Event('blur'));
        controls.update(1);
        _expectPose(camera, pose);
      },
    );
  }

  test('mouseleave ends drag and preserves completed movement', () {
    target.dispatchEvent(_mouse('mousedown', 0, 0));
    target.dispatchEvent(_mouse('mousemove', 10, 5));
    target.dispatchEvent(web.Event('mouseleave'));
    target.dispatchEvent(_mouse('mousemove', 100, 100));
    controls.update(0);
    expect(controls.azimuth, closeTo(0.1, 1e-12));
    expect(controls.polar, closeTo(0.05, 1e-12));
  });

  test(
    'zero size ignores input and discards pending gestures until restored',
    () {
      target.dispatchEvent(_key('keydown', 'ArrowLeft'));
      target.dispatchEvent(_wheel(10));
      final pose = camera.worldMatrix;
      target.style.height = '0px';
      final ignored = _wheel(20);
      target.dispatchEvent(ignored);
      expect(ignored.defaultPrevented, isFalse);
      controls.update(1);
      _expectPose(camera, pose);
      target.style.height = '240px';
      controls.update(1);
      _expectPose(camera, pose);
    },
  );

  test(
    'repeated lifecycle operations remove each registration exactly once',
    () async {
      controls.disable();
      final probe = _Probe(target);
      controls.enable();
      final count = probe.added.length;
      expect(count, greaterThan(0));
      controls.enable();
      expect(probe.added.length, count);
      controls
        ..disable()
        ..disable();
      expect(probe.removed.length, count);
      controls.enable();
      expect(probe.added.length, count * 2);
      final future = controls.dispose();
      expect(identical(controls.dispose(), future), isTrue);
      expect(controls.isDisposed, isTrue);
      expect(controls.enabled, isFalse);
      expect(probe.removed.length, count * 2);
      await future;
      for (final listener in probe.added) {
        expect(
          probe.removed.where(
            (removed) =>
                removed.type == listener.type &&
                removed.callback.strictEquals(listener.callback).toDart,
          ),
          hasLength(1),
        );
      }
      expect(controls.enable, throwsStateError);
      expect(() => controls.update(1), throwsStateError);
      expect(() => controls.radius = 2, throwsStateError);
      controls.disable();
      expect(probe.removed.length, count * 2);
    },
  );

  test('old saved callbacks remain inactive after re-enable', () {
    controls.disable();
    final probe = _Probe(target);
    controls.enable();
    final stale = List.of(probe.added);
    controls
      ..disable()
      ..enable();
    final key = _key('keydown', 'ArrowLeft');
    stale
        .singleWhere((listener) => listener.type == 'keydown')
        .callback
        .callAsFunction(target, key);
    expect(key.defaultPrevented, isFalse);
    controls.update(1);
    expect(controls.azimuth, 0);
  });

  test('invalid time preserves pose and pending wheel for the next update', () {
    target.dispatchEvent(_wheel(10));
    final pose = camera.worldMatrix;
    for (final delta in [-1.0, double.nan, double.infinity]) {
      expect(() => controls.update(delta), throwsArgumentError);
      _expectPose(camera, pose);
    }
    controls.update(0);
    expect(controls.radius, closeTo(10 * math.exp(0.02), 1e-10));
  });

  test('invalid configuration and overflowing input preserve the camera', () {
    final pose = camera.worldMatrix;
    expect(() => controls.radius = 0, throwsArgumentError);
    expect(() => controls.azimuth = double.nan, throwsArgumentError);
    expect(() => controls.polar = double.infinity, throwsArgumentError);
    expect(
      () => controls.target = vm.Vector3(double.nan, 0, 0),
      throwsArgumentError,
    );
    target.dispatchEvent(_key('keydown', 'PageDown'));
    expect(() => controls.update(1e308), throwsArgumentError);
    _expectPose(camera, pose);
    expect(controls.radius, 10);
    expect(controls.azimuth, 0);
  });

  test('pole clamp stays nonsingular and held reset respects zero time', () {
    controls.polar = math.pi;
    controls.update(0);
    expect(controls.polar, closeTo(math.pi / 2 - 0.1, 1e-12));
    expect(camera.viewMatrix.storage.every((value) => value.isFinite), isTrue);
    target.dispatchEvent(_key('keydown', 'Space'));
    controls.update(0);
    expect(controls.polar, isNonZero);
    controls.update(0.1);
    expect(controls.polar, 0);
    expect(controls.azimuth, 0);
  });
}
