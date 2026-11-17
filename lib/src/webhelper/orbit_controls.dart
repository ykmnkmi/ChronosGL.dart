import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

import '../camera/camera.dart';
import '../core/pose_math.dart';

/// Browser input controlling the world-space pose of a borrowed [camera].
///
/// Both keyboard and mouse listen to the explicit [eventTarget]. An element
/// needs focus (for example `canvas.tabIndex = 0`) to receive real key events.
/// Angles are radians: azimuth zero places the eye on +X, increasing toward +Z;
/// [polar] is elevation above XZ and is clamped away from the poles.
/// Configuration is applied by [update], including when its time step is zero.
/// The controller never changes camera projection or owns the camera/target.
class OrbitControls {
  OrbitControls(
    this.camera,
    this.eventTarget, {
    vm.Vector3? target,
    double radius = 10,
    double azimuth = 0,
    double polar = 0,
    this.rotationSpeed = 1.8,
    this.zoomSpeed = 0.6,
    this.dragRadiansPerPixel = 0.01,
    this.wheelZoomPerUnit = 0.002,
    this.wheelLineHeightCssPixels = 16,
    bool enabled = true,
  }) : _target = vm.Vector3.copy(target ?? vm.Vector3.zero()),
       _radius = _positive(radius, 'radius'),
       _azimuth = _finite(azimuth, 'azimuth'),
       _polar = _finite(polar, 'polar') {
    checkFiniteComponents(_target.storage, 'target');
    _nonnegative(rotationSpeed, 'rotationSpeed');
    _nonnegative(zoomSpeed, 'zoomSpeed');
    _nonnegative(dragRadiansPerPixel, 'dragRadiansPerPixel');
    _nonnegative(wheelZoomPerUnit, 'wheelZoomPerUnit');
    _positive(wheelLineHeightCssPixels, 'wheelLineHeightCssPixels');
    if (enabled) enable();
  }

  final Camera camera;
  final web.EventTarget eventTarget;

  /// Keyboard angular speed, in radians per second.
  final double rotationSpeed;

  /// Keyboard logarithmic radius speed, in inverse seconds.
  final double zoomSpeed;

  /// Drag sensitivity, in radians per CSS pixel; independent of frame time/DPR.
  final double dragRadiansPerPixel;

  /// Logarithmic radius change per normalized wheel CSS pixel.
  final double wheelZoomPerUnit;

  /// Explicit conversion from a wheel line to normalized CSS pixels.
  final double wheelLineHeightCssPixels;

  final vm.Vector3 _target;
  double _radius;
  double _azimuth;
  double _polar;
  bool _enabled = false;
  int _listenerEpoch = 0;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  final Set<int> _keys = {};
  final Set<int> _buttons = {};
  final List<({web.EventTarget target, String type, JSFunction callback})>
  _listeners = [];
  double _lastX = 0;
  double _lastY = 0;
  double _dragX = 0;
  double _dragY = 0;
  double _wheel = 0;

  bool get enabled => _enabled;
  bool get isDisposed => _disposed;
  set enabled(bool value) => value ? enable() : disable();

  vm.Vector3 get target => vm.Vector3.copy(_target);
  set target(vm.Vector3 value) {
    _checkAlive();
    checkFiniteComponents(value.storage, 'target');
    _target.setFrom(value);
  }

  double get radius => _radius;
  set radius(double value) {
    _checkAlive();
    _radius = _positive(value, 'radius');
  }

  double get azimuth => _azimuth;
  set azimuth(double value) {
    _checkAlive();
    _azimuth = _finite(value, 'azimuth');
  }

  double get polar => _polar;
  set polar(double value) {
    _checkAlive();
    _polar = _finite(value, 'polar');
  }

  /// Attaches fresh listeners once. Old held keys and deltas are never replayed.
  void enable() {
    _checkAlive();
    if (_enabled) return;
    _clearInput();
    _enabled = true;
    try {
      _listen(
        eventTarget,
        'keydown',
        ((web.KeyboardEvent event) {
          if (!_acceptInput) return;
          final key = _key(event);
          if (key == null) return;
          _keys.add(key);
          event.preventDefault();
        }).toJS,
      );
      _listen(
        eventTarget,
        'keyup',
        ((web.KeyboardEvent event) {
          if (!_enabled) return;
          final key = _key(event);
          if (key == null) return;
          _keys.remove(key);
          event.preventDefault();
        }).toJS,
      );
      _listen(
        eventTarget,
        'mousedown',
        ((web.MouseEvent event) {
          if (!_acceptInput || (event.button != 0 && event.button != 1)) return;
          _buttons.add(event.button);
          _lastX = event.clientX.toDouble();
          _lastY = event.clientY.toDouble();
          event.preventDefault();
        }).toJS,
      );
      _listen(
        eventTarget,
        'mousemove',
        ((web.MouseEvent event) {
          if (!_acceptInput || _buttons.isEmpty) return;
          final x = event.clientX.toDouble();
          final y = event.clientY.toDouble();
          _dragX += x - _lastX;
          _dragY += y - _lastY;
          _lastX = x;
          _lastY = y;
          event.preventDefault();
        }).toJS,
      );
      _listen(
        eventTarget,
        'mouseup',
        ((web.MouseEvent event) {
          if (!_enabled || !_buttons.remove(event.button)) return;
          event.preventDefault();
        }).toJS,
      );
      _listen(
        eventTarget,
        'mouseleave',
        ((web.Event event) {
          if (_enabled) _buttons.clear();
        }).toJS,
      );
      _listen(
        eventTarget,
        'wheel',
        ((web.WheelEvent event) {
          if (!_acceptInput || !event.deltaY.isFinite) return;
          final factor = switch (event.deltaMode) {
            0 => 1.0,
            1 => wheelLineHeightCssPixels,
            2 => _inputHeight,
            _ => 0.0,
          };
          _wheel += event.deltaY * factor;
          event.preventDefault();
        }).toJS,
        passive: false,
      );
      _listen(
        eventTarget,
        'blur',
        ((web.Event event) {
          if (_enabled) _clearInput();
        }).toJS,
      );
      if (!eventTarget.strictEquals(web.window).toDart) {
        _listen(
          web.window,
          'blur',
          ((web.Event event) {
            if (_enabled) _clearInput();
          }).toJS,
        );
      }
    } catch (_) {
      try {
        disable();
      } catch (_) {
        // Preserve the registration error after attempting every removal.
      }
      rethrow;
    }
  }

  /// Detaches listeners and clears all held and pending input immediately.
  /// Safe to repeat, including after [dispose].
  void disable() {
    _enabled = false;
    _listenerEpoch++;
    _clearInput();
    Object? firstError;
    StackTrace? firstStack;
    final listeners = List.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      try {
        listener.target.removeEventListener(listener.type, listener.callback);
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  /// Permanently detaches input. Repeated calls return the same completion.
  Future<void> dispose() {
    if (_disposeFuture != null) return _disposeFuture!;
    final completion = Completer<void>();
    _disposeFuture = completion.future;
    _disposed = true;
    try {
      disable();
      completion.complete();
    } catch (error, stack) {
      completion.completeError(error, stack);
    }
    return completion.future;
  }

  /// Applies continuous keyboard motion for finite, nonnegative seconds.
  ///
  /// Drag and normalized wheel events accumulate between successful updates,
  /// then are consumed exactly once without multiplying their deltas by time.
  /// A zero step consumes pending events but adds no held-key movement.
  /// A disabled controller leaves the camera unchanged. A zero-sized element
  /// discards input and leaves the pose unchanged until its area is restored.
  /// Invalid time/configuration or unrepresentable poses throw without changing
  /// the camera or consuming pending input. Calls after disposal throw StateError.
  void update(double deltaSeconds) {
    _checkAlive();
    _nonnegative(deltaSeconds, 'deltaSeconds');
    if (!_enabled) return;
    if (!_hasArea) {
      _clearInput();
      return;
    }
    var nextAzimuth = _azimuth + _dragX * dragRadiansPerPixel;
    var nextPolar = _polar + _dragY * dragRadiansPerPixel;
    nextAzimuth += (_axis(37, 39) * rotationSpeed) * deltaSeconds;
    nextPolar += (_axis(38, 40) * rotationSpeed) * deltaSeconds;
    final zoom = _axis(34, 33) * zoomSpeed * deltaSeconds;
    final nextRadius = _positive(
      _radius * math.exp(zoom + _wheel * wheelZoomPerUnit),
      'radius after input',
    );
    if (_keys.contains(32) && deltaSeconds > 0) {
      nextAzimuth = 0;
      nextPolar = 0;
    }
    _finite(nextAzimuth, 'azimuth after input');
    _finite(nextPolar, 'polar after input');
    nextPolar = nextPolar.clamp(-math.pi / 2 + 0.1, math.pi / 2 - 0.1);
    final eye = vm.Vector3(
      _target.x + nextRadius * math.cos(nextPolar) * math.cos(nextAzimuth),
      _target.y + nextRadius * math.sin(nextPolar),
      _target.z + nextRadius * math.cos(nextPolar) * math.sin(nextAzimuth),
    );
    checkFiniteComponents(eye.storage, 'eye after input');
    final rotation = lookAtRotation(eye, _target);
    camera.setPositionFromVector(eye);
    camera.setRotation(rotation);
    _azimuth = nextAzimuth;
    _polar = nextPolar;
    _radius = nextRadius;
    _dragX = _dragY = _wheel = 0;
  }

  bool get _hasArea =>
      !eventTarget.isA<web.Element>() ||
      ((eventTarget as web.Element).clientWidth > 0 &&
          (eventTarget as web.Element).clientHeight > 0);

  bool get _acceptInput => _enabled && _hasArea;

  double get _inputHeight => eventTarget.isA<web.Element>()
      ? (eventTarget as web.Element).clientHeight.toDouble()
      : web.window.innerHeight.toDouble();

  int _axis(int positive, int negative) =>
      (_keys.contains(positive) ? 1 : 0) - (_keys.contains(negative) ? 1 : 0);

  static int? _key(web.KeyboardEvent event) {
    final code = switch (event.code) {
      'ArrowLeft' => 37,
      'ArrowRight' => 39,
      'ArrowUp' => 38,
      'ArrowDown' => 40,
      'PageUp' => 33,
      'PageDown' => 34,
      'Space' => 32,
      _ => event.which,
    };
    return const {32, 33, 34, 37, 38, 39, 40}.contains(code) ? code : null;
  }

  void _listen(
    web.EventTarget target,
    String type,
    JSFunction callback, {
    bool passive = false,
  }) {
    final epoch = _listenerEpoch;
    final guarded = ((web.Event event) {
      if (_enabled && epoch == _listenerEpoch) {
        callback.callAsFunction(target, event);
      }
    }).toJS;
    _listeners.add((target: target, type: type, callback: guarded));
    target.addEventListener(
      type,
      guarded,
      web.AddEventListenerOptions(passive: passive),
    );
  }

  void _clearInput() {
    _keys.clear();
    _buttons.clear();
    _lastX = _lastY = _dragX = _dragY = _wheel = 0;
  }

  void _checkAlive() {
    if (_disposed) throw StateError('OrbitControls has been disposed');
  }

  static double _finite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'Must be finite');
    }
    return value;
  }

  static double _positive(double value, String name) {
    if (_finite(value, name) <= 0) {
      throw ArgumentError.value(value, name, 'Must be positive');
    }
    return value;
  }

  static double _nonnegative(double value, String name) {
    if (_finite(value, name) < 0) {
      throw ArgumentError.value(value, name, 'Must be nonnegative');
    }
    return value;
  }
}
