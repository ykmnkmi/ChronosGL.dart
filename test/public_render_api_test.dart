@TestOn('chrome')
library;

import 'package:chronosgl/camera.dart' as camera;
import 'package:chronosgl/chronosgl.dart' as engine;
import 'package:chronosgl/debug.dart' as debug;
import 'package:chronosgl/geometry.dart' as geometry;
import 'package:chronosgl/render.dart' as render;
import 'package:chronosgl/scene.dart' as scene;
import 'package:chronosgl/shaders.dart' as shaders;
import 'package:chronosgl/web.dart' as browser;
import 'package:chronosgl/webgl.dart' as webgl;
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

void main() {
  test('Public modules render a camera scene with typed uniforms and diagnostics', () {
    final canvas = web.HTMLCanvasElement()
      ..width = 8
      ..height = 8;
    final context = webgl.ChronosGL.fromCanvas(canvas, antialiasing: false);
    addTearDown(() {
      (context.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    final vertex =
        shaders.ShaderObject.create(
            name: 'public-vertex',
            stage: shaders.ShaderStage.vertex,
          )
          ..addAttributeVars([shaders.aPosition])
          ..addUniformVars([
            shaders.uPerspectiveViewMatrix,
            shaders.uModelMatrix,
          ])
          ..setBodyWithMain([
            'gl_Position = ${shaders.uPerspectiveViewMatrix} * ${shaders.uModelMatrix} * vec4(${shaders.aPosition}, 1.0);',
          ]);
    final fragment = shaders.ShaderObject.fragment('public-fragment')
      ..addUniformVars([shaders.uColor])
      ..setBodyWithMain([
        '${shaders.oFragColor} = vec4(${shaders.uColor}, 1.0);',
      ]);
    final program = render.RenderProgram.create(
      name: 'public-program',
      context: context,
      vertexShader: vertex,
      fragmentShader: fragment,
    );
    addTearDown(program.dispose);
    final mesh = render.uploadGeometry(
      'cube',
      program,
      geometry.cubeGeometry(),
    );
    addTearDown(mesh.dispose);
    final material = render.Material('red')
      ..set(render.UniformKeys.color, vm.Vector3(1, 0, 0));
    final view = camera.PerspectiveCamera(near: 0.1, far: 20)
      ..setPosition(0, 0, 5);
    final batch = scene.RenderBatch.named(
      name: 'objects',
      program: program,
      uniforms: [render.CameraUniforms(view)],
    )..add(scene.MeshNode('cube', mesh, material));
    final pass = scene.RenderPass.named(name: 'main', context: context)
      ..viewPortW = 8
      ..viewPortH = 8
      ..add(batch);
    final engine.RenderProgram aggregateProgram = program;
    expect(aggregateProgram, same(program));
    pass.draw();
    expect(pass.framebuffer.extractByteData(null, 4, 4, 1, 1), [
      255,
      0,
      0,
      255,
    ]);
    expect(context.getError(), webgl.glNoError);

    final root = web.HTMLDivElement();
    final panel = debug.FpsPanel.attach(root: root);
    panel.updateFrameCount(1000);
    expect(root.childElementCount, 1);
    panel.dispose();
    expect(root.childElementCount, 0);
    mesh.dispose();
    expect(() => pass.draw(), throwsStateError);
  });

  test(
    'Typed browser entrypoints share event targets and dispose cleanly',
    () async {
      final canvas = web.HTMLCanvasElement()
        ..width = 8
        ..height = 8
        ..style.width = '8px'
        ..style.height = '8px';
      web.document.body!.appendChild(canvas);
      addTearDown(() => canvas.remove());
      final context = webgl.ChronosGL.fromCanvas(canvas, antialiasing: false);
      addTearDown(() {
        (context.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
            ?.loseContext();
      });
      final keyboard = browser.Keyboard.forTarget(canvas);
      final mouse = browser.Mouse.forTarget(canvas);
      addTearDown(keyboard.dispose);
      addTearDown(mouse.dispose);
      canvas.dispatchEvent(
        web.KeyboardEvent(
          'keydown',
          web.KeyboardEventInit(
            which: browser.Keyboard.left,
            keyCode: browser.Keyboard.left,
          ),
        ),
      );
      canvas.dispatchEvent(web.MouseEvent('mousedown'));
      expect(keyboard.currentlyPressedKey(browser.Keyboard.left), isTrue);
      expect(mouse.currentlyPressedButton(browser.Mouse.left), isTrue);
      final view = camera.PerspectiveCamera(near: 0.1, far: 20);
      final controls = browser.OrbitControls.forCamera(
        camera: view,
        eventTarget: canvas,
        radius: 5,
      );
      addTearDown(controls.dispose);
      controls.update(0);
      expect(view.worldPosition.length, closeTo(5, 0.00001));
      final viewport = browser.CanvasViewport.forCanvas(
        cgl: context,
        canvas: canvas,
        camera: view,
        pixelRatio: 1,
      );
      addTearDown(viewport.dispose);
      expect(viewport.pixelRatio, 1);
      expect(
        () => browser.OrbitControls.forCamera(
          camera: view,
          eventTarget: canvas,
          radius: 0,
        ),
        throwsArgumentError,
      );
      await keyboard.dispose();
      await mouse.dispose();
      canvas.dispatchEvent(web.KeyboardEvent('keydown'));
      canvas.dispatchEvent(web.MouseEvent('mousedown'));
      expect(keyboard.currentlyPressedKey(browser.Keyboard.left), isFalse);
      expect(mouse.currentlyPressedButton(browser.Mouse.left), isFalse);
    },
  );
}
