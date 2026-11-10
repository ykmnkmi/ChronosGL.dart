@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// A deletion counter alone misses leaks; native is* alone misses double deletes.
// Keep every handle so both properties can be checked after each scene cycle.
class _Handles<T> {
  final created = <T>[];
  final deleted = <T>[];

  T record(T handle) {
    created.add(handle);
    return handle;
  }

  void expectReleased(String kind, bool Function(T) isLive) {
    expect(
      deleted,
      unorderedEquals(created),
      reason: '$kind deleted once each',
    );
    for (final handle in created) {
      expect(isLive(handle), isFalse, reason: '$kind no longer live');
    }
  }
}

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final buffers = _Handles<GlBuffer>();
  final vaos = _Handles<GlVertexArrayObject>();
  final textures = _Handles<GlTexture>();
  final programs = _Handles<GlProgram>();
  final shaders = _Handles<GlShader>();
  final framebuffers = _Handles<GlFramebuffer>();

  @override
  GlBuffer createBuffer() => buffers.record(super.createBuffer());

  @override
  GlVertexArrayObject createVertexArray() =>
      vaos.record(super.createVertexArray());

  @override
  GlTexture createTexture() => textures.record(super.createTexture());

  @override
  GlProgram createProgram() => programs.record(super.createProgram());

  @override
  GlShader createShader(int kind) => shaders.record(super.createShader(kind));

  @override
  GlFramebuffer createFramebuffer() =>
      framebuffers.record(super.createFramebuffer());

  @override
  void deleteBuffer(GlBuffer handle) {
    buffers.deleted.add(handle);
    super.deleteBuffer(handle);
  }

  @override
  void deleteVertexArray(GlVertexArrayObject handle) {
    vaos.deleted.add(handle);
    super.deleteVertexArray(handle);
  }

  @override
  void deleteTexture(GlTexture handle) {
    textures.deleted.add(handle);
    super.deleteTexture(handle);
  }

  @override
  void deleteProgram(GlProgram handle) {
    programs.deleted.add(handle);
    super.deleteProgram(handle);
  }

  @override
  void deleteShader(GlShader handle) {
    shaders.deleted.add(handle);
    super.deleteShader(handle);
  }

  @override
  void deleteFramebuffer(GlFramebuffer handle) {
    framebuffers.deleted.add(handle);
    super.deleteFramebuffer(handle);
  }

  void expectReleased(web.WebGL2RenderingContext gl) {
    // WebGL defers deletion of the current program until it is unbound.
    gl.useProgram(null);
    buffers.expectReleased('buffer', (handle) => gl.isBuffer(handle));
    vaos.expectReleased('VAO', (handle) => gl.isVertexArray(handle));
    textures.expectReleased('texture', (handle) => gl.isTexture(handle));
    programs.expectReleased('program', (handle) => gl.isProgram(handle));
    shaders.expectReleased('shader', (handle) => gl.isShader(handle));
    framebuffers.expectReleased(
      'framebuffer',
      (handle) => gl.isFramebuffer(handle),
    );
    expect(gl.isContextLost(), isFalse);
    expect(getError(), glNoError);
  }
}

RenderProgram _program(ChronosGL cgl) {
  final vertex = ShaderObject('lifecycle-v')
    ..addAttributeVars([aPosition])
    ..addUniformVars([uModelMatrix])
    ..setBodyWithMain(['gl_Position = $uModelMatrix * vec4($aPosition, 1.0);']);
  final fragment = ShaderObject('lifecycle-f')
    ..addUniformVars([uTexture])
    ..setBodyWithMain(['$oFragColor = texture($uTexture, vec2(0.5));']);
  final program = RenderProgram('lifecycle', cgl, vertex, fragment);
  addTearDown(program.dispose);
  return program;
}

Uint8List _pixels(List<int> color) =>
    Uint8List.fromList([for (var i = 0; i < 4; i++) ...color]);

const _green = [0, 255, 0, 255];
const _red = [255, 0, 0, 255];

TypedTextureMutable _texture(ChronosGL cgl, List<int> color) {
  final texture = TypedTextureMutable(
    cgl,
    'scene sampler',
    2,
    2,
    glRgba,
    texturePropertiesFramebuffer,
    glRgba,
    glUnsignedByte,
    _pixels(color),
  );
  addTearDown(texture.dispose);
  return texture;
}

MeshData _mesh(RenderProgram program) {
  final mesh = program.makeMeshData('shared triangle', glTriangles);
  addTearDown(mesh.dispose);
  mesh
    ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]))
    ..addFaces([0, 1, 2]);
  return mesh;
}

RenderPhase _phase(ChronosGL cgl, Framebuffer target, List<Scene> scenes) {
  final phase = RenderPhase('lifecycle', cgl, target)
    ..viewPortW = 2
    ..viewPortH = 2;
  for (final scene in scenes) {
    phase.add(scene);
  }
  return phase;
}

void _expectDraw(RenderPhase phase, int draws, [List<int> color = _green]) {
  final stats = <DrawStats>[];
  phase.draw(stats);
  expect(stats, hasLength(draws));
  expect(phase.framebuffer.extractByteData(null, 0, 0, 2, 2), _pixels(color));
}

List<web.Event> _inputEvents() => [
  web.KeyboardEvent(
    'keydown',
    web.KeyboardEventInit(
      which: Keyboard.a,
      keyCode: Keyboard.a,
      cancelable: true,
    ),
  ),
  web.KeyboardEvent(
    'keyup',
    web.KeyboardEventInit(
      which: Keyboard.b,
      keyCode: Keyboard.b,
      cancelable: true,
    ),
  ),
  web.MouseEvent(
    'mousedown',
    web.MouseEventInit(button: Mouse.left, cancelable: true),
  ),
  web.MouseEvent(
    'mouseup',
    web.MouseEventInit(button: Mouse.right, cancelable: true),
  ),
  web.MouseEvent(
    'mousemove',
    web.MouseEventInit(
      clientX: 3,
      clientY: 4,
      movementX: 5,
      movementY: -2,
      cancelable: true,
    ),
  ),
  web.WheelEvent('wheel', web.WheelEventInit(deltaY: 7, cancelable: true)),
];

void _expectInputCleared(Keyboard keyboard, Mouse mouse) {
  expect(keyboard.isDisposed, isTrue);
  expect(mouse.isDisposed, isTrue);
  for (final key in [Keyboard.a, Keyboard.b]) {
    expect(keyboard.currentlyPressedKey(key), isFalse);
    expect(keyboard.justPressedKey(key), isFalse);
    expect(keyboard.justReleasedKey(key), isFalse);
  }
  for (final button in [Mouse.left, Mouse.right]) {
    expect(mouse.currentlyPressedButton(button), isFalse);
    expect(mouse.justPressedButton(button), isFalse);
    expect(mouse.justReleasedButton(button), isFalse);
  }
  expect(
    [
      mouse.currentX,
      mouse.currentY,
      mouse.moveDeltaX,
      mouse.moveDeltaY,
      mouse.wheelDeltaY,
    ],
    [0, 0, 0, 0, 0],
  );
}

void main() {
  late web.HTMLCanvasElement canvas;
  late _TrackingGL cgl;
  late web.WebGL2RenderingContext gl;

  setUp(() {
    canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = _TrackingGL(canvas);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    cgl.disable(glDepthTest);
    cgl.disable(glDither);
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
  });

  for (final withDepth in [false, true]) {
    test(
      'Scene cycles release all owned resources and input (depth=$withDepth)',
      () async {
        final previousInputs = <({Keyboard keyboard, Mouse mouse})>[];
        for (var cycle = 0; cycle < 5; cycle++) {
          final program = _program(cgl);
          final mesh = _mesh(program);
          final sampler = _texture(cgl, _green);
          final material = Material.empty('shared')
            ..setUniform(uTexture, sampler);
          final scene = Scene('cycle $cycle', program)
            ..add(Node('first', mesh, material))
            ..add(Node('second', mesh, material));
          final target = withDepth
              ? Framebuffer.defaultFramebuffer(cgl, 2, 2)
              : Framebuffer.effect(cgl, 2, 2);
          addTearDown(target.dispose);
          final attachments = [?target.colorTexture, ?target.depthTexture];
          final phase = _phase(cgl, target, [scene]);
          final keyboard = Keyboard(canvas);
          final mouse = Mouse(canvas);
          addTearDown(keyboard.dispose);
          addTearDown(mouse.dispose);

          final events = _inputEvents();
          for (final event in events) {
            canvas.dispatchEvent(event);
          }
          expect(keyboard.currentlyPressedKey(Keyboard.a), isTrue);
          expect(keyboard.justReleasedKey(Keyboard.b), isTrue);
          expect(mouse.currentlyPressedButton(Mouse.left), isTrue);
          expect(mouse.justReleasedButton(Mouse.right), isTrue);
          expect(
            [mouse.moveDeltaX, mouse.moveDeltaY, mouse.wheelDeltaY],
            [5, -2, 7],
          );
          expect(events.last.defaultPrevented, isTrue);
          for (final old in previousInputs) {
            _expectInputCleared(old.keyboard, old.mouse);
          }
          _expectDraw(phase, 2);

          // The application owns this bundle. Stop input, remove graph links,
          // then explicitly release GPU owners; Scene itself has no dispose().
          final keyboardDone = keyboard.dispose();
          final mouseDone = mouse.dispose();
          expect(identical(keyboard.dispose(), keyboardDone), isTrue);
          expect(identical(mouse.dispose(), mouseDone), isTrue);
          scene.removeAll();
          for (var repeat = 0; repeat < 2; repeat++) {
            target.dispose();
            mesh.dispose();
            program.dispose();
            sampler.dispose();
            for (final attachment in attachments) {
              attachment.dispose();
            }
          }
          previousInputs.add((keyboard: keyboard, mouse: mouse));

          void expectDisconnected() {
            for (final event in _inputEvents()) {
              expect(canvas.dispatchEvent(event), isTrue);
              expect(event.defaultPrevented, isFalse, reason: event.type);
            }
            for (final old in previousInputs) {
              _expectInputCleared(old.keyboard, old.mouse);
            }
          }

          expectDisconnected();
          await Future.wait([keyboardDone, mouseDone]);
          expect(identical(keyboard.dispose(), keyboardDone), isTrue);
          expect(identical(mouse.dispose(), mouseDone), isTrue);
          expectDisconnected();
          expect(scene.nodes, isEmpty);
          expect(
            mesh.isDisposed &&
                program.isDisposed &&
                sampler.isDisposed &&
                target.isDisposed,
            isTrue,
          );
          for (final attachment in attachments) {
            expect(attachment.isDisposed, isTrue);
          }
          expect(cgl.buffers.created, hasLength((cycle + 1) * 2));
          expect(cgl.vaos.created, hasLength(cycle + 1));
          expect(
            cgl.textures.created,
            hasLength((cycle + 1) * (withDepth ? 3 : 2)),
          );
          expect(cgl.programs.created, hasLength(cycle + 1));
          expect(cgl.shaders.created, hasLength((cycle + 1) * 2));
          expect(cgl.framebuffers.created, hasLength(cycle + 1));
          cgl.expectReleased(gl);
        }
      },
    );
  }

  for (final removal in ['scene.remove', 'scene.removeAll', 'DAG child']) {
    test('$removal preserves shared mesh, material and the remaining draw', () {
      final program = _program(cgl);
      final mesh = _mesh(program);
      final green = _texture(cgl, _green);
      final red = _texture(cgl, _red);
      final material = Material.empty('shared')..setUniform(uTexture, green);
      final node = Node('shared', mesh, material);
      final first = Scene('first', program);
      final second = Scene('second', program);
      final branch = Node.container('first branch', node);
      late void Function() remove;
      late void Function() restore;
      switch (removal) {
        case 'scene.remove':
          first
            ..add(node)
            ..add(Node('other consumer', mesh, material));
          remove = () => first.remove(node);
          restore = () => first.add(node);
        case 'scene.removeAll':
          first.add(node);
          second.add(node);
          remove = first.removeAll;
          restore = () => first.add(node);
        case 'DAG child':
          first
            ..add(branch)
            ..add(Node.container('second branch', node));
          remove = () => branch.children.remove(node);
          restore = () => branch.add(node);
      }
      final target = Framebuffer.effect(cgl, 2, 2);
      addTearDown(target.dispose);
      final phase = _phase(cgl, target, [first, second]);
      _expectDraw(phase, 2);
      remove();
      remove();
      expect(mesh.isDisposed, isFalse);
      expect(program.isDisposed, isFalse);
      expect(green.isDisposed, isFalse);
      expect(node.material, same(material));
      expect(material.getUniforms()[uTexture], same(green));
      expect(cgl.buffers.deleted, isEmpty);
      expect(cgl.vaos.deleted, isEmpty);
      expect(cgl.textures.deleted, isEmpty);
      expect(cgl.programs.deleted, isEmpty);
      expect(cgl.framebuffers.deleted, isEmpty);
      _expectDraw(phase, 1);

      // The remaining node still reads the very same material, including edits.
      material.forceUniform(uTexture, red);
      _expectDraw(phase, 1, _red);
      restore();
      _expectDraw(phase, 2, _red);
      first.removeAll();
      second.removeAll();
      branch.children.clear();
      target.dispose();
      mesh.dispose();
      program.dispose();
      green.dispose();
      red.dispose();
      cgl.expectReleased(gl);
    });
  }

  test(
    'Destroying one scene consumer leaves shared resources usable by another',
    () {
      final firstProgram = _program(cgl);
      final secondProgram = _program(cgl);
      final mesh = _mesh(firstProgram);
      final sampler = _texture(cgl, _green);
      final material = Material.empty('shared')..setUniform(uTexture, sampler);
      final node = Node('shared', mesh, material);
      final first = Scene('first', firstProgram)..add(node);
      final second = Scene('second', secondProgram)..add(node);
      final color = TypedTexture(
        cgl,
        'shared output',
        2,
        2,
        glRgba8,
        texturePropertiesFramebuffer,
      );
      addTearDown(color.dispose);
      final firstTarget = Framebuffer(cgl, color, null);
      final secondTarget = Framebuffer(cgl, color, null);
      addTearDown(firstTarget.dispose);
      addTearDown(secondTarget.dispose);
      final firstPhase = _phase(cgl, firstTarget, [first]);
      final secondPhase = _phase(cgl, secondTarget, [second]);
      _expectDraw(firstPhase, 1);
      first.removeAll();
      for (var repeat = 0; repeat < 2; repeat++) {
        firstTarget.dispose();
        firstProgram.dispose();
      }
      expect(cgl.programs.deleted, [cgl.programs.created.first]);
      expect(cgl.framebuffers.deleted, [cgl.framebuffers.created.first]);
      expect(cgl.buffers.deleted, isEmpty);
      expect(cgl.vaos.deleted, isEmpty);
      expect(cgl.textures.deleted, isEmpty);
      expect(firstProgram.hasCompatibleAttributesTo(secondProgram), isTrue);
      _expectDraw(secondPhase, 1);
      expect(gl.isProgram(cgl.programs.created.first), isFalse);
      sampler.updateContent(_pixels(_red), glRgba, glUnsignedByte);
      _expectDraw(secondPhase, 1, _red);
      second.removeAll();
      secondTarget.dispose();
      secondProgram.dispose();
      expect(cgl.textures.deleted, isEmpty);
      expect(gl.isTexture(color.getTexture()), isTrue);
      mesh.dispose();
      sampler.dispose();
      color.dispose();
      cgl.expectReleased(gl);
    },
  );
}
