@TestOn('chrome && dart2js')
library;

// Intentionally exercise legacy callers while they migrate to package:web.
// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:web_gl' as webgl;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

ChronosGL _context(html.CanvasElement canvas) {
  final cgl = ChronosGL(canvas, antialiasing: false);
  addTearDown(() {
    (cgl.getExtension('WEBGL_lose_context') as webgl.LoseContext?)
        ?.loseContext();
  });
  return cgl;
}

void main() {
  test('Migrated helpers accept legacy DOM elements during migration', () {
    final canvas = html.CanvasElement(width: 32, height: 16)
      ..style.width = '32px'
      ..style.height = '16px';
    html.document.body!.append(canvas);
    addTearDown(() => canvas.remove());
    final target = JSObject.fromInteropObject(canvas) as web.HTMLCanvasElement;
    final keyboard = Keyboard(canvas);
    final mouse = Mouse(canvas);
    final orbit = OrbitCamera(10, 0, 0, canvas);
    target.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(which: Keyboard.left, keyCode: Keyboard.left),
      ),
    );
    expect(keyboard.currentlyPressedKey(Keyboard.left), isTrue);
    target.dispatchEvent(
      web.KeyboardEvent(
        'keyup',
        web.KeyboardEventInit(which: Keyboard.left, keyCode: Keyboard.left),
      ),
    );
    target.dispatchEvent(web.MouseEvent('mousedown'));
    expect(mouse.currentlyPressedButton(Mouse.left), isTrue);
    expect(orbit.mouse.currentlyPressedButton(Mouse.left), isTrue);
    target.dispatchEvent(web.MouseEvent('mouseup'));
    final root = html.DivElement();
    StatsFps(root, 'blue', 'gray').updateFrameCount(1000, '<b>legacy</b>');
    expect(root.querySelector('b')!.text, 'legacy');
    final cgl = _context(canvas);
    final perspective = PerspectiveResizeAware(cgl, canvas, orbit, 0.1, 100);
    final phase = RenderPhaseResizeAware('legacy', cgl, canvas, perspective);
    expect([phase.viewPortW, phase.viewPortH], [32, 16]);
    expect(cgl.getParameter(glViewport), [0, 0, 32, 16]);
  });

  test('Legacy canvas textures upload and update through modern bindings', () {
    final cgl = _context(html.CanvasElement(width: 2, height: 2));
    final source = html.CanvasElement(width: 2, height: 2);
    final paint = source.context2D
      ..fillStyle = '#336699'
      ..fillRect(0, 0, 2, 2);
    final texture = ImageTexture(
      cgl,
      'legacy',
      source,
      texturePropertiesFramebuffer,
    );
    final framebuffer = Framebuffer(cgl, texture);
    expect(framebuffer.extractByteData(null, 0, 0, 1, 1), [51, 102, 153, 255]);
    paint
      ..fillStyle = '#ff0000'
      ..fillRect(0, 0, 2, 2);
    texture.update();
    expect(framebuffer.extractByteData(null, 0, 0, 1, 1), [255, 0, 0, 255]);
    expect(cgl.getError(), glNoError);
  });
}
