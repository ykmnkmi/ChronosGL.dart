@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

@JS('Object.defineProperty')
external JSObject _defineProperty(
  JSObject target,
  JSString key,
  JSObject descriptor,
);

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _getDescriptor(JSObject target, JSString key);

@JS('Reflect.deleteProperty')
external bool _deleteProperty(JSObject target, JSString key);

@JS('globalThis')
external JSObject get _global;

void _override(JSObject target, String name, JSAny value) {
  final descriptor = _getDescriptor(target, name.toJS);
  _defineProperty(
    target,
    name.toJS,
    <String, Object?>{'configurable': true, 'value': value}.jsify()!
        as JSObject,
  );
  addTearDown(() {
    if (descriptor == null) {
      _deleteProperty(target, name.toJS);
    } else {
      _defineProperty(target, name.toJS, descriptor);
    }
  });
}

web.HTMLCanvasElement _canvas([String width = '80px', String height = '40px']) {
  final canvas = web.HTMLCanvasElement()
    ..style.width = width
    ..style.height = height;
  web.document.body!.appendChild(canvas);
  addTearDown(() => canvas.remove());
  return canvas;
}

ChronosGL _context(web.HTMLCanvasElement canvas) {
  final cgl = ChronosGL(canvas, antialiasing: false);
  addTearDown(() {
    final extension = cgl.getExtension('WEBGL_lose_context');
    if (extension != null) (extension as web.WEBGL_lose_context).loseContext();
  });
  return cgl;
}

PerspectiveCamera _camera() => PerspectiveCamera(near: 0.1, far: 100);

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; ++attempt) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Resize observer did not synchronize the canvas');
}

void main() {
  test('DPR scales content box and synchronizes camera and screen pass', () {
    final canvas = _canvas();
    final cgl = _context(canvas);
    final camera = _camera()..setPosition(1, 2, 3);
    final phase = RenderPhase('screen', cgl);
    final viewport = CanvasViewport(
      cgl,
      canvas,
      camera,
      renderPhase: phase,
      pixelRatio: 1.5,
    );
    addTearDown(viewport.dispose);
    expect(viewport.isReady, isTrue);
    expect([canvas.width, canvas.height], [120, 60]);
    expect(cgl.getParameter(glViewport), [0, 0, 120, 60]);
    expect([phase.viewPortW, phase.viewPortH], [120, 60]);
    expect(camera.aspectRatio, 2);
    expect(camera.worldPosition.storage, [1, 2, 3]);
    expect([camera.near, camera.far], [0.1, 100]);
    expect([canvas.style.width, canvas.style.height], ['80px', '40px']);
  });

  test('fractional content box rounds once excluding borders and padding', () {
    final canvas = _canvas('85.5px', '45.25px')
      ..style.boxSizing = 'border-box'
      ..style.padding = '2px'
      ..style.border = '1px solid black';
    final viewport = CanvasViewport(
      _context(canvas),
      canvas,
      _camera(),
      pixelRatio: 1.5,
    );
    addTearDown(viewport.dispose);
    expect(viewport.widthCssPixels, 79.5);
    expect(viewport.heightCssPixels, 39.25);
    expect([canvas.width, canvas.height], [119, 59]);
  });

  test('element resize updates without a window resize event', () async {
    final parent = web.HTMLDivElement()..style.width = '100px';
    web.document.body!.appendChild(parent);
    addTearDown(() => parent.remove());
    final canvas = _canvas('100%', '40px');
    parent.appendChild(canvas);
    final camera = _camera();
    final viewport = CanvasViewport(
      _context(canvas),
      canvas,
      camera,
      pixelRatio: 1,
    );
    addTearDown(viewport.dispose);
    expect(canvas.width, 100);
    parent.style.width = '60px';
    await _until(() => canvas.width == 60);
    expect(camera.aspectRatio, 1.5);
    expect(canvas.style.width, '100%');
  });

  test(
    'hidden and zero-sized canvas preserve projection and recover',
    () async {
      final canvas = _canvas();
      final cgl = _context(canvas);
      final camera = _camera();
      final phase = RenderPhase('screen', cgl);
      final viewport = CanvasViewport(
        cgl,
        canvas,
        camera,
        renderPhase: phase,
        pixelRatio: 1,
      );
      addTearDown(viewport.dispose);
      final projection = camera.projection;
      canvas.style.display = 'none';
      await _until(() => !viewport.isReady);
      expect(camera.projection, same(projection));
      expect([phase.viewPortW, phase.viewPortH], [0, 0]);
      expect(phase.draw, returnsNormally);
      canvas.style
        ..display = 'block'
        ..width = '0px';
      expect(viewport.update(), isFalse);
      expect(camera.projection, same(projection));
      canvas.style
        ..width = '40px'
        ..height = '80px';
      await _until(() => viewport.isReady);
      expect([canvas.width, canvas.height], [40, 80]);
      expect(camera.aspectRatio, 0.5);
      expect([phase.viewPortW, phase.viewPortH], [40, 80]);
      expect(phase.draw, returnsNormally);
    },
  );

  test(
    'partial viewport uses physical pixel aspect and zero area skips draw',
    () {
      final canvas = _canvas();
      final cgl = _context(canvas);
      final camera = _camera();
      final phase = RenderPhase('screen', cgl);
      final viewport = CanvasViewport(
        cgl,
        canvas,
        camera,
        renderPhase: phase,
        pixelRatio: 2,
      );
      addTearDown(viewport.dispose);
      viewport.setViewport(x: 7, y: 9, width: 30, height: 60);
      expect(cgl.getParameter(glViewport), [7, 9, 30, 60]);
      expect([phase.viewPortX, phase.viewPortY], [7, 9]);
      expect(camera.aspectRatio, 0.5);
      final projection = camera.projection;
      viewport.setViewport(width: 0, height: 60);
      expect(viewport.isReady, isFalse);
      expect(camera.projection, same(projection));
      expect(phase.draw, returnsNormally);
      expect(
        () => viewport.setViewport(width: -1, height: 4),
        throwsArgumentError,
      );
      phase.viewPortW = -1;
      expect(phase.draw, throwsArgumentError);
      viewport.useFullViewport();
      expect(cgl.getParameter(glViewport), [0, 0, 160, 80]);
      expect(camera.aspectRatio, 2);
    },
  );

  test('orthographic explicit bounds remain unchanged', () {
    final canvas = _canvas();
    final camera = OrthographicCamera(
      left: -2,
      right: 3,
      bottom: -4,
      top: 5,
      near: -1,
      far: 20,
    );
    final projection = camera.projection;
    final viewport = CanvasViewport(
      _context(canvas),
      canvas,
      camera,
      pixelRatio: 2,
    );
    addTearDown(viewport.dispose);
    canvas.style.width = '20px';
    viewport.update();
    expect(camera.projection, same(projection));
    expect([canvas.width, canvas.height], [40, 80]);
  });

  test(
    'disable detaches observers and resize listener; enable resynchronizes',
    () async {
      final canvas = _canvas();
      final cgl = _context(canvas);
      final camera = _camera();
      final viewport = CanvasViewport(cgl, canvas, camera, pixelRatio: 1);
      addTearDown(viewport.dispose);
      final projection = camera.projection;
      viewport.disable();
      viewport.disable();
      canvas.style.width = '30px';
      web.window.dispatchEvent(web.Event('resize'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(viewport.update(), isFalse);
      expect(canvas.width, 80);
      expect(camera.projection, same(projection));
      viewport.enable();
      viewport.enable();
      expect(canvas.width, 30);
      expect(camera.aspectRatio, 0.75);
      canvas.style.width = '40px';
      await _until(() => canvas.width == 40);
      expect(camera.aspectRatio, 1);
    },
  );

  test('dispose is final, idempotent and preserves borrowed objects', () async {
    final canvas = _canvas();
    final cgl = _context(canvas);
    final camera = _camera();
    final phase = RenderPhase('screen', cgl);
    final viewport = CanvasViewport(
      cgl,
      canvas,
      camera,
      renderPhase: phase,
      pixelRatio: 1,
    );
    viewport.dispose();
    viewport.dispose();
    canvas.style.width = '30px';
    web.window.dispatchEvent(web.Event('resize'));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(canvas.width, 80);
    expect(viewport.isDisposed, isTrue);
    expect(viewport.enabled, isFalse);
    expect(viewport.update, throwsStateError);
    expect(viewport.enable, throwsStateError);
    expect(() => viewport.pixelRatio = 2, throwsStateError);
    expect(() => viewport.setViewport(width: 2, height: 2), throwsStateError);
    expect(viewport.useFullViewport, throwsStateError);
    expect(camera.aspectRatio, 2);
    expect(phase.draw, returnsNormally);
    expect(cgl.getError(), glNoError);
  });

  test(
    'disposal attempts listener cleanup after observer disconnect fails',
    () {
      final canvas = _canvas();
      final viewport = CanvasViewport(_context(canvas), canvas, _camera());
      final prototype = _global
          .getProperty<JSObject>('ResizeObserver'.toJS)
          .getProperty<JSObject>('prototype'.toJS);
      final disconnect = prototype.getProperty<JSFunction>('disconnect'.toJS);
      void failingDisconnect(JSObject receiver) {
        disconnect.callAsFunction(receiver);
        throw StateError('disconnect failure');
      }

      _override(prototype, 'disconnect', failingDisconnect.toJSCaptureThis);
      final remove = web.window.getProperty<JSFunction>(
        'removeEventListener'.toJS,
      );
      final removed = <String>[];
      _override(
        web.window,
        'removeEventListener',
        ((JSString type, JSFunction listener, [JSAny? options]) {
          removed.add(type.toDart);
          remove.callAsFunction(web.window, type, listener, options);
        }).toJS,
      );
      expect(viewport.dispose, throwsA(isA<StateError>()));
      expect(removed, contains('resize'));
      expect(viewport.isDisposed, isTrue);
      expect(viewport.enabled, isFalse);
      expect(viewport.dispose, returnsNormally);
      canvas.style.width = '20px';
      web.window.dispatchEvent(web.Event('resize'));
      expect(canvas.width, 80);
    },
  );

  test('density changes automatically rearm their media query', () {
    final canvas = _canvas();
    _override(web.window, 'devicePixelRatio', 1.toJS);
    final original = web.window.getProperty<JSFunction>('matchMedia'.toJS);
    final queries = <web.MediaQueryList>[];
    _override(
      web.window,
      'matchMedia',
      ((JSString query) {
        final result = original.callAsFunction(web.window, query)!;
        queries.add(result as web.MediaQueryList);
        return result;
      }).toJS,
    );
    final viewport = CanvasViewport(_context(canvas), canvas, _camera());
    addTearDown(viewport.dispose);
    expect(canvas.width, 80);
    final firstQuery = queries.single;
    _defineProperty(
      web.window,
      'devicePixelRatio'.toJS,
      <String, Object?>{'configurable': true, 'value': 2}.jsify()! as JSObject,
    );
    firstQuery.dispatchEvent(web.Event('change'));
    expect([canvas.width, canvas.height], [160, 80]);
    expect(queries.length, 2);
    viewport.disable();
    canvas.style.width = '20px';
    queries.last.dispatchEvent(web.Event('change'));
    expect(canvas.width, 160);
    viewport.enable();
    expect(canvas.width, 40);
    final activeQuery = queries.last;
    viewport.pixelRatio = 1.5;
    expect(canvas.width, 30);
    canvas.style.width = '10px';
    activeQuery.dispatchEvent(web.Event('change'));
    expect(canvas.width, 30);
    viewport.pixelRatio = null;
    expect(canvas.width, 20);
    expect(queries.length, 4);
  });

  test(
    'actual drawing-buffer dimensions determine full viewport and aspect',
    () {
      final canvas = _canvas();
      final cgl = _context(canvas);
      final gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
      _override(gl, 'drawingBufferWidth', 63.toJS);
      _override(gl, 'drawingBufferHeight', 31.toJS);
      final camera = _camera();
      final viewport = CanvasViewport(cgl, canvas, camera, pixelRatio: 2);
      addTearDown(viewport.dispose);
      expect([canvas.width, canvas.height], [160, 80]);
      expect(cgl.getParameter(glViewport), [0, 0, 63, 31]);
      expect(camera.aspectRatio, 63 / 31);
      expect(
        [viewport.drawingBufferWidthPixels, viewport.drawingBufferHeightPixels],
        [63, 31],
      );
    },
  );

  test(
    'tiny positive CSS dimensions allocate one pixel; invalid density rejects',
    () {
      final canvas = _canvas('0.25px', '0.25px');
      final cgl = _context(canvas);
      final viewport = CanvasViewport(cgl, canvas, _camera(), pixelRatio: 0.1);
      addTearDown(viewport.dispose);
      expect([canvas.width, canvas.height], [1, 1]);
      for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => viewport.pixelRatio = ratio, throwsArgumentError);
        expect(viewport.pixelRatio, 0.1);
      }
      expect(
        () => CanvasViewport(cgl, canvas, _camera(), pixelRatio: 0),
        throwsArgumentError,
      );
    },
  );
}
