@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

web.HTMLCanvasElement _canvas(int width, int height) => web.HTMLCanvasElement()
  ..width = width
  ..height = height;

ChronosGL _context(web.HTMLCanvasElement canvas) {
  final cgl = ChronosGL(canvas, antialiasing: false);
  addTearDown(() {
    final extension = cgl.getExtension('WEBGL_lose_context');
    if (extension != null) (extension as web.WEBGL_lose_context).loseContext();
  });
  return cgl;
}

web.KeyboardEvent _key(String type, int key) =>
    web.KeyboardEvent(type, web.KeyboardEventInit(which: key, keyCode: key));

void _stopStream(web.MediaStream stream) {
  for (final track in stream.getTracks().toDart) {
    track.stop();
  }
}

void _releaseVideo(web.HTMLVideoElement video) {
  video.pause();
  video.srcObject = null;
  video.removeAttribute('src');
  video.load();
}

void main() {
  late String baseUrl;
  setUpAll(() async {
    final server = spawnHybridUri('support/webhelper_assets.dart');
    baseUrl = await server.stream.first as String;
    addTearDown(() => server.sink.add('stop'));
  });

  test('Keyboard tracks held keys and clears per-frame transitions', () {
    final target = web.HTMLDivElement();
    final keyboard = Keyboard(target);
    target.dispatchEvent(_key('keydown', Keyboard.a));
    expect(keyboard.currentlyPressedKey(Keyboard.a), isTrue);
    expect(keyboard.justPressedKey(Keyboard.a), isTrue);
    keyboard.afterFrameCleanup();
    expect(keyboard.currentlyPressedKey(Keyboard.a), isTrue);
    expect(keyboard.justPressedKey(Keyboard.a), isFalse);
    target.dispatchEvent(_key('keyup', Keyboard.a));
    expect(keyboard.currentlyPressedKey(Keyboard.a), isFalse);
    expect(keyboard.justReleasedKey(Keyboard.a), isTrue);
    keyboard.afterFrameCleanup();
    expect(keyboard.justReleasedKey(Keyboard.a), isFalse);
  });

  test(
    'Null input targets listen on the document and cancel wheel scrolling',
    () {
      final keyboard = Keyboard(null);
      final mouse = Mouse(null);
      web.document.dispatchEvent(_key('keydown', Keyboard.space));
      expect(keyboard.currentlyPressedKey(Keyboard.space), isTrue);
      web.document.dispatchEvent(_key('keyup', Keyboard.space));
      final wheel = web.WheelEvent(
        'wheel',
        web.WheelEventInit(deltaY: -12.5, cancelable: true),
      );
      web.document.dispatchEvent(wheel);
      expect(mouse.wheelDeltaY, -12);
      expect(wheel.defaultPrevented, isTrue);
      mouse.afterFrameCleanup();
      expect(mouse.wheelDeltaY, 0);
    },
  );

  test(
    'Mouse preserves local coordinates, movement, and button transitions',
    () {
      final target = _canvas(100, 80)
        ..style.position = 'absolute'
        ..style.left = '20px'
        ..style.top = '30px';
      web.document.body!.appendChild(target);
      addTearDown(() => target.remove());
      final mouse = Mouse(target);
      final move = web.MouseEvent(
        'mousemove',
        web.MouseEventInit(
          clientX: 37,
          clientY: 49,
          movementX: 7,
          movementY: -3,
          cancelable: true,
        ),
      );
      target.dispatchEvent(move);
      expect([mouse.currentX, mouse.currentY], [17, 19]);
      expect([mouse.moveDeltaX, mouse.moveDeltaY], [7, -3]);
      expect(move.defaultPrevented, isTrue);
      target.dispatchEvent(
        web.MouseEvent('mousedown', web.MouseEventInit(button: 2)),
      );
      expect(mouse.currentlyPressedButton(Mouse.right), isTrue);
      expect(mouse.justPressedButton(Mouse.right), isTrue);
      mouse.afterFrameCleanup();
      expect(mouse.currentlyPressedButton(Mouse.right), isTrue);
      expect(mouse.justPressedButton(Mouse.right), isFalse);
      expect([mouse.moveDeltaX, mouse.moveDeltaY], [0, 0]);
      target.dispatchEvent(
        web.MouseEvent('mouseup', web.MouseEventInit(button: 2)),
      );
      expect(mouse.currentlyPressedButton(Mouse.right), isFalse);
      expect(mouse.justReleasedButton(Mouse.right), isTrue);
      mouse.afterFrameCleanup();
      expect(mouse.justReleasedButton(Mouse.right), isFalse);
    },
  );

  test('OrbitCamera consumes modern canvas input and resets frame deltas', () {
    final canvas = _canvas(32, 32);
    final camera = OrbitCamera(10, 0, 0, canvas);
    canvas.dispatchEvent(web.MouseEvent('mousedown'));
    canvas.dispatchEvent(
      web.MouseEvent(
        'mousemove',
        web.MouseEventInit(movementX: 10, movementY: 5),
      ),
    );
    camera.animate(16);
    expect(camera.azimuth, closeTo(0.1, 1e-8));
    expect(camera.polar, closeTo(0.05, 1e-8));
    expect(camera.getPos().storage.every((value) => value.isFinite), isTrue);
    expect(camera.mouse.moveDeltaX, 0);
    canvas.dispatchEvent(web.MouseEvent('mouseup'));
    camera.animate(16);
    expect(camera.azimuth, closeTo(0.1, 1e-8));
  });

  test('Stats updates DOM markup and rotates a fixed, clamped graph', () {
    final root = web.HTMLDivElement();
    final stats = Stats(root, 'blue', 'gray');
    expect(root.children.length, 3);
    final graph = root.children.item(1)! as web.HTMLElement;
    expect(graph.children.length, 90);
    final first = graph.firstChild!;
    stats.addRawValue(100);
    expect(graph.lastChild!.strictEquals(first).toDart, isTrue);
    expect((graph.lastChild! as web.HTMLElement).style.height, '30px');
    stats.addRawValue(-5);
    expect((graph.lastChild! as web.HTMLElement).style.height, '0px');
    expect(graph.children.length, 90);
    stats.changeExtra('<b>draw calls</b>');
    expect(root.querySelector('b')!.textContent, 'draw calls');
  });

  test(
    'StatsFps samples frames and displays formatted text and extra markup',
    () {
      final root = web.HTMLDivElement();
      final fps = StatsFps(root, 'blue', 'gray');
      for (var frame = 1; frame <= 60; frame++) {
        fps.updateFrameCount(frame * 1000 / 60, '<b>60 frames</b>');
      }
      expect(root.firstChild!.textContent, '60.00 fps');
      expect(root.querySelector('b')!.textContent, '60 frames');
      final graph = root.children.item(1)!;
      expect((graph.lastChild! as web.HTMLElement).style.height, '20px');
    },
  );

  test('Resize helpers follow CSS size and update projection and viewport', () {
    final canvas = _canvas(2, 2)
      ..style.width = '80px'
      ..style.height = '40px';
    web.document.body!.appendChild(canvas);
    addTearDown(() => canvas.remove());
    final cgl = _context(canvas);
    final camera = Spatial('camera');
    final perspective = PerspectiveResizeAware(cgl, canvas, camera, 0.1, 100);
    final phase = RenderPhaseResizeAware('phase', cgl, canvas, perspective);
    expect([canvas.width, canvas.height], [80, 40]);
    expect(cgl.getParameter(glViewport), [0, 0, 80, 40]);
    final initial =
        perspective.getUniforms()[uPerspectiveViewMatrix]! as vm.Matrix4;
    expect(initial.entry(1, 1) / initial.entry(0, 0), closeTo(2, 1e-8));
    canvas.style
      ..width = '60px'
      ..height = '80px';
    web.window.dispatchEvent(web.Event('resize'));
    expect([canvas.width, canvas.height], [60, 80]);
    expect([phase.viewPortW, phase.viewPortH], [60, 80]);
    expect(cgl.getParameter(glViewport), [0, 0, 60, 80]);
    final resized =
        perspective.getUniforms()[uPerspectiveViewMatrix]! as vm.Matrix4;
    expect(resized.entry(1, 1) / resized.entry(0, 0), closeTo(0.75, 1e-8));
  });

  test('Canvas helpers produce solid colors and a radial particle texture', () {
    final canvas = makeSolidColorCanvas('#336699');
    expect([canvas.width, canvas.height], [2, 2]);
    final paint = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    expect(paint.getImageData(0, 0, 1, 1).data.toDart, [51, 102, 153, 255]);
    final particle = Utils.createParticleCanvas();
    expect([particle.width, particle.height], [64, 64]);
    final gradient = particle.getContext('2d') as web.CanvasRenderingContext2D;
    final center = gradient.getImageData(32, 32, 1, 1).data.toDart;
    final edge = gradient.getImageData(0, 0, 1, 1).data.toDart;
    expect(center[0], greaterThan(200));
    expect(edge, [0, 0, 0, 255]);
  });

  test('Solid canvas textures upload RGB and alpha through WebGL', () {
    final cgl = _context(_canvas(2, 2));
    final rgb = makeSolidColorTextureRGB(cgl, 'rgb', vm.Vector3(0.2, 0.4, 0.6));
    expect(Framebuffer(cgl, rgb).extractByteData(null, 0, 0, 1, 1), [
      51,
      102,
      153,
      255,
    ]);
    final rgba = makeSolidColorTextureRGBA(
      cgl,
      'rgba',
      vm.Vector4(1, 0, 0, 0.5),
    );
    final pixels = Framebuffer(cgl, rgba).extractByteData(null, 0, 0, 1, 1);
    expect(pixels.sublist(0, 3), [255, 0, 0]);
    expect(pixels[3], closeTo(128, 1));
    expect(cgl.getError(), glNoError);
  });

  group('Asset loading', () {
    test('Text and JSON cross the browser request boundary', () async {
      expect(await loadRaw('$baseUrl/text'), 'ChronosGL assets');
      expect(await loadJson('$baseUrl/json'), {
        'name': 'scene',
        'vertices': [1, 2, 3],
      });
    });

    test('HTTP and JSON errors complete the returned futures', () async {
      await expectLater(loadRaw('$baseUrl/missing'), throwsStateError);
      await expectLater(
        loadJson('$baseUrl/broken-json'),
        throwsFormatException,
      );
      await expectLater(loadJson('$baseUrl/missing'), throwsStateError);
      await expectLater(loadRaw('$baseUrl/disconnect'), throwsStateError);
    });

    test('Images load and cube faces retain their documented order', () async {
      final image = await loadImage('$baseUrl/image.png');
      expect([image.naturalWidth, image.naturalHeight], [256, 256]);
      final images = await Future.wait(
        loadCubeImages('$baseUrl/cube_', '.png'),
      );
      expect(images.map((image) => image.src), [
        for (final face in ['nx', 'px', 'ny', 'py', 'nz', 'pz'])
          '$baseUrl/cube_$face.png',
      ]);
      expect(
        images.every((image) => image.complete && image.naturalWidth == 256),
        isTrue,
      );
    });

    test('Image and video failures complete instead of hanging', () async {
      await expectLater(loadImage('$baseUrl/missing'), throwsStateError);
      await expectLater(loadVideo('$baseUrl/missing'), throwsStateError);
    });
  });

  test('Video loader resolves with a playing, looping video', () async {
    final video = await loadVideo('$baseUrl/video.webm');
    addTearDown(() => _releaseVideo(video));
    expect(video.autoplay, isTrue);
    expect(video.loop, isTrue);
    expect(video.paused, isFalse);
    expect([video.videoWidth, video.videoHeight], [32, 32]);
    expect(video.readyState, greaterThanOrEqualTo(2));
  });

  test(
    'Camera uses mediaDevices and returns a playing video-backed stream',
    () async {
      final devices = web.window.navigator.mediaDevices;
      final original = devices.getProperty<JSFunction>('getUserMedia'.toJS);
      addTearDown(() => devices.setProperty('getUserMedia'.toJS, original));
      final response = await web.window
          .fetch('$baseUrl/video.webm'.toJS)
          .toDart;
      final url = web.URL.createObjectURL(await response.blob().toDart);
      addTearDown(() => web.URL.revokeObjectURL(url));
      final source = await loadVideo(url);
      addTearDown(() => _releaseVideo(source));
      final stream = source.callMethod<web.MediaStream>('captureStream'.toJS);
      addTearDown(() => _stopStream(stream));
      web.MediaStreamConstraints? requested;
      devices.setProperty(
        'getUserMedia'.toJS,
        ((web.MediaStreamConstraints constraints) {
          requested = constraints;
          return Future.value(stream).toJS;
        }).toJS,
      );
      final video = (await makeVideoElementFromCamera())!;
      addTearDown(() => _releaseVideo(video));
      expect((requested!.video as JSBoolean).toDart, isTrue);
      expect(video.srcObject!.strictEquals(stream).toDart, isTrue);
      expect(video.autoplay && video.muted && video.playsInline, isTrue);
      expect(video.paused, isFalse);
      expect([video.videoWidth, video.videoHeight], [32, 32]);
      final cgl = _context(_canvas(32, 32));
      final texture = ImageTexture(
        cgl,
        'camera',
        video,
        texturePropertiesVideo,
      );
      final pixels = Framebuffer(
        cgl,
        texture,
      ).extractByteData(null, 0, 0, 1, 1);
      expect(pixels[0], closeTo(255, 3));
      expect(pixels[1], closeTo(0, 3));
      expect(pixels[2], closeTo(0, 3));
      expect(pixels[3], 255);
      texture.update();
      expect(cgl.getError(), glNoError);
    },
  );

  test('Camera rejection keeps the nullable failure result', () async {
    final devices = web.window.navigator.mediaDevices;
    final original = devices.getProperty<JSFunction>('getUserMedia'.toJS);
    addTearDown(() => devices.setProperty('getUserMedia'.toJS, original));
    devices.setProperty(
      'getUserMedia'.toJS,
      ((web.MediaStreamConstraints constraints) {
        return Future<web.MediaStream>.error(StateError('Camera denied')).toJS;
      }).toJS,
    );
    expect(await makeVideoElementFromCamera(), isNull);
  });
}
