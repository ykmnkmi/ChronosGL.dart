@TestOn('chrome')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../example/shared/lifetime.dart';

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super.fromCanvas(antialiasing: false);

  int buffersCreated = 0;
  int buffersDeleted = 0;
  int texturesCreated = 0;
  int texturesDeleted = 0;
  int programsDeleted = 0;
  int vaosDeleted = 0;
  int framebuffersDeleted = 0;

  @override
  GlBuffer createBuffer() {
    buffersCreated++;
    return super.createBuffer();
  }

  @override
  void deleteBuffer(GlBuffer buffer) {
    buffersDeleted++;
    super.deleteBuffer(buffer);
  }

  @override
  GlTexture createTexture() {
    texturesCreated++;
    return super.createTexture();
  }

  @override
  void deleteTexture(GlTexture texture) {
    texturesDeleted++;
    super.deleteTexture(texture);
  }

  @override
  void deleteProgram(GlProgram program) {
    programsDeleted++;
    super.deleteProgram(program);
  }

  @override
  void deleteVertexArray(GlVertexArrayObject vao) {
    vaosDeleted++;
    super.deleteVertexArray(vao);
  }

  @override
  void deleteFramebuffer(GlFramebuffer framebuffer) {
    framebuffersDeleted++;
    super.deleteFramebuffer(framebuffer);
  }
}

class _ThrowingUniforms extends UniformGroup {
  _ThrowingUniforms(this.failure) : super('injected failure');

  final Object failure;

  @override
  Map<String, Object> getUniforms() => throw failure;
}

_TrackingGL _context() {
  final canvas = web.HTMLCanvasElement()
    ..width = 2
    ..height = 2;
  final context = _TrackingGL(canvas);
  addTearDown(() {
    (context.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
        ?.loseContext();
  });
  return context;
}

RenderProgram _program(ChronosGL context) => RenderProgram.create(
  name: 'example lifetime',
  context: context,
  vertexShader: texturedVertexShader,
  fragmentShader: texturedFragmentShader,
);

ImageTexture _texture(ChronosGL context) => ImageTexture.fromCanvas(
  context: context,
  canvas: web.HTMLCanvasElement()
    ..width = 2
    ..height = 2,
  properties: texturePropertiesFramebuffer,
);

void main() {
  for (final ownPass in [false, true]) {
    final owner = ownPass ? 'pass' : 'batch';
    test('camera uniform texture extras follow $owner ownership', () async {
      final context = _context();
      final lifetime = ExampleLifetime();
      addTearDown(lifetime.dispose);
      final program = _program(context);
      final camera = PerspectiveCamera(near: 0.1, far: 100);
      final initialTexture = _texture(context);
      final uniforms = CameraUniforms(camera)
        ..set(UniformKeys.texture, initialTexture);
      final batch = RenderBatch('camera textures', program, [uniforms]);
      if (ownPass) {
        lifetime.ownPass(RenderPass('camera textures', context)..add(batch));
      } else {
        lifetime.ownBatch(batch);
      }

      final finalTexture = _texture(context);
      uniforms.force(UniformKeys.texture, finalTexture);
      expect(initialTexture.isDisposed, isFalse);
      expect(finalTexture.isDisposed, isFalse);
      await lifetime.dispose();
      expect(initialTexture.isDisposed, isTrue);
      expect(finalTexture.isDisposed, isTrue);
      expect(context.texturesDeleted, context.texturesCreated);
      expect(program.isDisposed, isTrue);
      expect(camera.worldPosition.storage, [0, 0, 0]);
    });
  }

  test('pass ownership covers initial and final resources and deduplicates DAGs', () async {
    final context = _context();
    final lifetime = ExampleLifetime();
    addTearDown(lifetime.dispose);
    final program = _program(context);
    final oldMesh = shapeQuad(program, 1);
    final oldTexture = _texture(context);
    final material = Material('material')..set(UniformKeys.texture, oldTexture);
    final batch = RenderBatch('objects', program)
      ..add(MeshNode('old', oldMesh, material));
    final framebuffer = Framebuffer.effect(context, 2, 2);
    final pass = RenderPass('owned pass', context, framebuffer)..add(batch);
    lifetime
      ..ownPass(pass)
      ..ownBatch(batch)
      ..own(program);

    // Scene links and texture values may change after registration. Previously
    // captured resources and the final graph both remain owned by the example.
    batch.removeAll();
    final newMesh = shapeQuad(program, 0.5);
    final newTexture = _texture(context);
    material.force(UniformKeys.texture, newTexture);
    final shared = MeshNode('shared', newMesh, material);
    final group = GroupNode('root')
      ..add(GroupNode('left', shared))
      ..add(GroupNode('right', shared));
    group.add(group); // Teardown must tolerate cycles as well as shared nodes.
    batch.add(group);
    pass.add(RenderBatch('added later', program)..add(shared));

    final disposal = lifetime.dispose();
    expect(lifetime.dispose(), same(disposal));
    await disposal;
    expect([oldMesh.isDisposed, newMesh.isDisposed], everyElement(isTrue));
    expect([
      oldTexture.isDisposed,
      newTexture.isDisposed,
    ], everyElement(isTrue));
    expect(framebuffer.isDisposed, isTrue);
    expect(program.isDisposed, isTrue);
    expect(context.buffersDeleted, context.buffersCreated);
    expect(context.texturesDeleted, context.texturesCreated);
    expect(context.programsDeleted, 1);
    expect(context.vaosDeleted, 2);
    expect(context.framebuffersDeleted, 1);
  });

  test(
    'late resources release immediately while asynchronous cleanup is pending',
    () async {
      final context = _context();
      final lifetime = ExampleLifetime();
      final gate = Completer<void>();
      var completed = false;
      lifetime.onDispose(() => gate.future);
      final disposal = lifetime.dispose().then((_) => completed = true);
      expect(lifetime.isDisposed, isTrue);
      expect(completed, isFalse);

      final texture = lifetime.own(_texture(context));
      expect(texture.isDisposed, isTrue);
      var cancellations = 0;
      final controller = StreamController<int>(onCancel: () => cancellations++);
      lifetime.own(controller.stream.listen((_) {}));
      expect(cancellations, 1);
      gate.complete();
      await disposal;
      await controller.close();
      expect(completed, isTrue);
    },
  );

  test(
    'cleanup errors retain the first failure and still cancel subscriptions',
    () async {
      final lifetime = ExampleLifetime();
      final failure = StateError('injected cleanup failure');
      var cancellations = 0;
      var released = 0;
      final controller = StreamController<int>(onCancel: () => cancellations++);
      lifetime
        ..own(controller.stream.listen((_) {}))
        ..onDispose(() => released++)
        ..onDispose(() => throw failure);
      final disposal = lifetime.dispose();
      expect(lifetime.dispose(), same(disposal));
      await expectLater(disposal, throwsA(same(failure)));
      await controller.close();
      expect(cancellations, 1);
      expect(released, 1);
    },
  );

  test(
    'teardown cancels frames and disables input before awaiting cleanup',
    () async {
      final lifetime = ExampleLifetime();
      addTearDown(lifetime.dispose);
      final canvas = web.HTMLCanvasElement();
      final keyboard = lifetime.own(Keyboard.forTarget(canvas));
      final controls = lifetime.own(
        OrbitControls.forCamera(
          camera: PerspectiveCamera(near: 0.1, far: 100),
          eventTarget: canvas,
        ),
      );
      void press() => canvas.dispatchEvent(
        web.KeyboardEvent(
          'keydown',
          web.KeyboardEventInit(which: Keyboard.left, keyCode: Keyboard.left),
        ),
      );
      press();
      expect(keyboard.currentlyPressedKey(Keyboard.left), isTrue);
      var frames = 0;
      final callback = ((double _) => frames++).toJS;
      lifetime.requestAnimationFrame(callback);
      final disposal = lifetime.dispose();
      expect([keyboard.isDisposed, controls.isDisposed], everyElement(isTrue));
      press();
      expect(keyboard.currentlyPressedKey(Keyboard.left), isFalse);
      expect(lifetime.requestAnimationFrame(callback), 0);
      final nextFrame = Completer<void>();
      web.window.requestAnimationFrame(
        ((double _) => nextFrame.complete()).toJS,
      );
      await nextFrame.future;
      await disposal;
      expect(frames, 0);
    },
  );

  test(
    'pagehide retains cached pages and disposes pages leaving the cache',
    () async {
      final lifetime = ExampleLifetime();
      addTearDown(lifetime.dispose);
      var released = 0;
      lifetime.onDispose(() => released++);
      web.window.dispatchEvent(
        web.PageTransitionEvent(
          'pagehide',
          web.PageTransitionEventInit(persisted: true),
        ),
      );
      expect(lifetime.isDisposed, isFalse);
      expect(released, 0);
      web.window.dispatchEvent(web.PageTransitionEvent('pagehide'));
      expect(lifetime.isDisposed, isTrue);
      await lifetime.dispose();
      expect(released, 1);
    },
  );

  test(
    'a final uniform read failure does not skip later owned GPU resources',
    () async {
      final context = _context();
      final lifetime = ExampleLifetime();
      final firstProgram = _program(context);
      final firstBatch = RenderBatch('first', firstProgram);
      final pass = lifetime.ownPass(
        RenderPass('owned', context)..add(firstBatch),
      );
      final failure = StateError('injected final uniform read failure');
      firstBatch.uniforms.add(_ThrowingUniforms(failure));
      final mesh = shapeQuad(firstProgram, 1);
      final texture = _texture(context);
      final material = Material('late material')
        ..set(UniformKeys.texture, texture);
      firstBatch.add(MeshNode('late node', mesh, material));
      final secondProgram = _program(context);
      pass.add(RenderBatch('second', secondProgram));

      await expectLater(lifetime.dispose(), throwsA(same(failure)));
      expect(mesh.isDisposed, isTrue);
      expect(texture.isDisposed, isTrue);
      expect([
        firstProgram.isDisposed,
        secondProgram.isDisposed,
      ], everyElement(isTrue));
      expect(context.buffersDeleted, context.buffersCreated);
      expect(context.texturesDeleted, context.texturesCreated);
    },
  );
}
