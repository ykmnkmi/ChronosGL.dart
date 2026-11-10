@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

const _vertex = '''#version 300 es
void main() { gl_Position = vec4(0.0, 0.0, 0.0, 1.0); }
''';
const _fragment = '''#version 300 es
precision mediump float;
out vec4 color;
void main() { color = vec4(1.0); }
''';

// Inject failures around real WebGL operations. Counters detect skipped and
// duplicate deletions; native is* queries also detect deferred shader deletion.
class _FailingGL extends ChronosGL {
  _FailingGL(super.canvas) : super(antialiasing: false);

  final programs = <GlProgram>[];
  final shaders = <GlShader>[];
  final textures = <GlTexture>[];
  final framebuffers = <GlFramebuffer>[];
  final deletedPrograms = <GlProgram>[];
  final deletedShaders = <GlShader>[];
  final deletedTextures = <GlTexture>[];
  final deletedFramebuffers = <GlFramebuffer>[];
  final failAt = <String, int>{};
  final calls = <String, int>{};
  final failure = StateError('injected creation failure');
  final failureStack = StackTrace.fromString('original construction stack');
  bool failDeletes = false;
  bool failProgramDelete = false;

  void checkpoint(String operation) {
    final count = (calls[operation] ?? 0) + 1;
    calls[operation] = count;
    if (failAt[operation] == count) {
      Error.throwWithStackTrace(failure, failureStack);
    }
  }

  void afterDelete() {
    if (failDeletes) throw StateError('secondary deletion failure');
  }

  @override
  GlProgram createProgram() {
    checkpoint('program');
    final value = super.createProgram();
    programs.add(value);
    return value;
  }

  @override
  GlShader createShader(int kind) {
    checkpoint('shader');
    final value = super.createShader(kind);
    shaders.add(value);
    return value;
  }

  @override
  void linkProgram(GlProgram program) {
    checkpoint('link');
    super.linkProgram(program);
  }

  @override
  GlUniformLocation? getUniformLocation(GlProgram program, String name) {
    checkpoint('uniform');
    return super.getUniformLocation(program, name);
  }

  @override
  GlTexture createTexture() {
    checkpoint('texture');
    final value = super.createTexture();
    textures.add(value);
    return value;
  }

  @override
  void texStorage2D(int target, int levels, int format, int width, int height) {
    checkpoint('storage');
    super.texStorage2D(target, levels, format, width, height);
  }

  @override
  void texParameteri(int target, int name, int value) {
    checkpoint('settings');
    super.texParameteri(target, name, value);
  }

  @override
  void texImage2Dweb(
    int target,
    int level,
    int internalFormat,
    int format,
    int type,
    Object data,
  ) {
    checkpoint('image');
    super.texImage2Dweb(target, level, internalFormat, format, type, data);
  }

  @override
  GlFramebuffer createFramebuffer() {
    checkpoint('framebuffer');
    final value = super.createFramebuffer();
    framebuffers.add(value);
    return value;
  }

  @override
  void bindFramebuffer(int target, GlFramebuffer? framebuffer) {
    super.bindFramebuffer(target, framebuffer);
    checkpoint(framebuffer == null ? 'unbind' : 'bind');
  }

  @override
  void framebufferTexture2D(
    int target,
    int attachment,
    int textureTarget,
    GlTexture texture,
    int level,
  ) {
    super.framebufferTexture2D(
      target,
      attachment,
      textureTarget,
      texture,
      level,
    );
    checkpoint('attachment');
  }

  @override
  int checkFramebufferStatus(int target) {
    checkpoint('status');
    return super.checkFramebufferStatus(target);
  }

  @override
  void deleteProgram(GlProgram value) {
    deletedPrograms.add(value);
    super.deleteProgram(value);
    if (failProgramDelete) {
      throw StateError('secondary program deletion failure');
    }
    afterDelete();
  }

  @override
  void deleteShader(GlShader value) {
    deletedShaders.add(value);
    super.deleteShader(value);
    afterDelete();
  }

  @override
  void deleteTexture(GlTexture value) {
    deletedTextures.add(value);
    super.deleteTexture(value);
    afterDelete();
  }

  @override
  void deleteFramebuffer(GlFramebuffer value) {
    deletedFramebuffers.add(value);
    super.deleteFramebuffer(value);
    afterDelete();
  }
}

// Named constructors remain generative and usable by subclasses.
class _Effect extends Framebuffer {
  _Effect(ChronosGL cgl) : super.effect(cgl, 2, 2);
}

void main() {
  late _FailingGL cgl;
  late web.WebGL2RenderingContext gl;

  setUp(() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = _FailingGL(canvas);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
  });

  void expectReleased() {
    expect(cgl.deletedPrograms, unorderedEquals(cgl.programs));
    expect(cgl.deletedShaders, unorderedEquals(cgl.shaders));
    expect(cgl.deletedTextures, unorderedEquals(cgl.textures));
    expect(cgl.deletedFramebuffers, unorderedEquals(cgl.framebuffers));
    for (final handle in cgl.programs) {
      expect(gl.isProgram(handle), isFalse);
    }
    for (final handle in cgl.shaders) {
      expect(gl.isShader(handle), isFalse);
    }
    for (final handle in cgl.textures) {
      expect(gl.isTexture(handle), isFalse);
    }
    for (final handle in cgl.framebuffers) {
      expect(gl.isFramebuffer(handle), isFalse);
    }
    expect(cgl.getError(), glNoError);
  }

  void expectOriginalFailure(void Function() action) {
    Object? caught;
    StackTrace? trace;
    try {
      action();
    } catch (error, stack) {
      caught = error;
      trace = stack;
    }
    expect(caught, same(cgl.failure));
    expect(trace.toString(), cgl.failureStack.toString());
  }

  TypedTexture texture([int format = glRgba8]) =>
      TypedTexture(cgl, 'external', 2, 2, format, texturePropertiesFramebuffer);

  // Keep distinct read/draw targets and a texture alive outside the tracked
  // constructors. Failure must restore these exact handles, not just bind null.
  void Function() saveBindings() {
    final read = gl.createFramebuffer()!;
    final draw = gl.createFramebuffer()!;
    final tex = gl.createTexture()!;
    gl.bindFramebuffer(glReadFramebuffer, read);
    gl.bindFramebuffer(glDrawFramebuffer, draw);
    gl.bindTexture(glTexture2D, tex);
    return () {
      expect(cgl.getParameter(glReadFramebufferBinding), read);
      expect(cgl.getParameter(glDrawFramebufferBinding), draw);
      expect(cgl.getParameter(glTextureBinding2D), tex);
      expect(gl.isFramebuffer(read), isTrue);
      expect(gl.isFramebuffer(draw), isTrue);
      expect(gl.isTexture(tex), isTrue);
    };
  }

  for (final stage in ['vertex', 'fragment']) {
    test('A real $stage compile error releases every partial handle', () {
      expect(
        () => cgl.compileWholeProgram(
          stage == 'vertex' ? 'invalid vertex shader' : _vertex,
          stage == 'fragment' ? 'invalid fragment shader' : _fragment,
          [],
        ),
        throwsA(isA<String>().having((e) => e, 'compiler log', isNotEmpty)),
      );
      expect(cgl.shaders, hasLength(stage == 'vertex' ? 1 : 2));
      expect(cgl.programs, hasLength(1));
      expectReleased();
    });
  }

  test('A real varying mismatch releases both shaders and the program', () {
    expect(
      () => cgl.compileWholeProgram(
        '''#version 300 es
out vec3 varyingValue;
void main() { varyingValue = vec3(1.0); gl_Position = vec4(1.0); }
''',
        '''#version 300 es
precision mediump float;
in vec4 varyingValue;
out vec4 color;
void main() { color = varyingValue; }
''',
        [],
      ),
      throwsA(isA<String>()),
    );
    expect(cgl.shaders, hasLength(2));
    expectReleased();
  });

  test('Invalid transform feedback varying cleans up after link failure', () {
    expect(
      () => cgl.compileWholeProgram(_vertex, _fragment, ['missing']),
      throwsA(isA<String>()),
    );
    expect(cgl.shaders, hasLength(2));
    expectReleased();
  });

  for (final entry in [
    ('program', 1, 0),
    ('shader', 1, 0),
    ('shader', 2, 1),
    ('link', 1, 2),
  ]) {
    test(
      'Failure at ${entry.$1} #${entry.$2} preserves its error and stack',
      () {
        cgl.failAt[entry.$1] = entry.$2;
        cgl.failDeletes = true;
        expectOriginalFailure(
          () => cgl.compileWholeProgram(_vertex, _fragment, []),
        );
        expect(cgl.shaders, hasLength(entry.$3));
        expectReleased();
      },
    );
  }

  test(
    'Failure deleting a linked shader still releases the remaining resources',
    () {
      cgl.failDeletes = true;
      expect(
        () => cgl.compileWholeProgram(_vertex, _fragment, []),
        throwsStateError,
      );
      expect(cgl.shaders, hasLength(2));
      expectReleased();
    },
  );

  test('RenderProgram releases a linked program when uniform initialization fails', () {
    final vertex = ShaderObject('v')
      ..addAttributeVars([aPosition])
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('f')
      ..addUniformVars([uTexture])
      ..setBodyWithMain(['$oFragColor = texture($uTexture, vec2(0.5));']);
    cgl.failAt['uniform'] = 1;
    // Let successful shader cleanup finish; fail the program deletion instead.
    cgl.failProgramDelete = true;
    expectOriginalFailure(
      () => RenderProgram('failure', cgl, vertex, fragment),
    );
    expect(cgl.programs, hasLength(1));
    expectReleased();
  });

  test(
    'A failed compile preserves the current program and permits a new compile',
    () {
      final current = cgl.compileWholeProgram(_vertex, _fragment, []);
      cgl.useProgram(current);
      cgl.failAt['shader'] = 4;
      expectOriginalFailure(
        () => cgl.compileWholeProgram(_vertex, _fragment, []),
      );
      expect(cgl.getParameter(glCurrentProgram), current);
      expect(gl.isProgram(current), isTrue);
      final next = cgl.compileWholeProgram(_vertex, _fragment, []);
      expect(gl.getAttachedShaders(next)!.toDart, isEmpty);
      expect(gl.isProgram(next), isTrue);
      gl.useProgram(null);
      cgl.deleteProgram(current);
      cgl.deleteProgram(next);
      expectReleased();
    },
  );

  test(
    'An incomplete framebuffer releases its handle and restores bindings',
    () {
      final checkBindings = saveBindings();
      expect(() => Framebuffer(cgl, null), throwsStateError);
      expect(cgl.framebuffers, hasLength(1));
      checkBindings();
      expectReleased();
    },
  );

  test('A real attachment format error leaves borrowed textures alive', () {
    final external = texture(glDepthComponent24);
    final checkBindings = saveBindings();
    expect(() => Framebuffer(cgl, external), throwsStateError);
    checkBindings();
    expect(cgl.deletedTextures, isEmpty);
    expect(external.isDisposed, isFalse);
    expect(gl.isTexture(external.getTexture()), isTrue);
    external.dispose();
    expectReleased();
  });

  test('A disposed attachment is rejected before allocating a framebuffer', () {
    final external = texture()..dispose();
    final checkBindings = saveBindings();
    expect(() => Framebuffer(cgl, external), throwsStateError);
    checkBindings();
    expect(cgl.framebuffers, isEmpty);
    expectReleased();
  });

  test('Conflicting stencil arguments are rejected before allocation', () {
    final external = texture();
    final checkBindings = saveBindings();
    expect(
      () => Framebuffer(cgl, external, external, external, true),
      throwsArgumentError,
    );
    checkBindings();
    expect(cgl.framebuffers, isEmpty);
    expect(cgl.deletedTextures, isEmpty);
    external.dispose();
    expectReleased();
  });

  for (final owned in [false, true]) {
    for (final operation in [
      'framebuffer',
      'bind',
      'attachment',
      'status',
      'unbind',
    ]) {
      test(
        '$operation failure cleans up ${owned ? 'owned' : 'borrowed'} framebuffer',
        () {
          final external = owned ? null : texture();
          final checkBindings = saveBindings();
          cgl.failAt[operation] = 1;
          cgl.failDeletes = true;
          expectOriginalFailure(
            () => owned
                ? Framebuffer.defaultFramebuffer(cgl, 2, 2)
                : Framebuffer(cgl, external),
          );
          checkBindings();
          expect(
            cgl.framebuffers,
            hasLength(operation == 'framebuffer' ? 0 : 1),
          );
          if (external != null) {
            expect(cgl.deletedTextures, isEmpty);
            expect(external.isDisposed, isFalse);
            expect(gl.isTexture(external.getTexture()), isTrue);
            cgl.failDeletes = false;
            external.dispose();
          } else {
            expect(cgl.textures, hasLength(2));
          }
          expectReleased();
        },
      );
    }
  }

  for (final entry in [
    ('texture', 1, 0),
    ('texture', 2, 1),
    ('storage', 1, 1),
    ('storage', 2, 2),
    ('settings', 1, 1),
    ('settings', 5, 2),
  ]) {
    test(
      'Framebuffer attachment ${entry.$1} #${entry.$2} failure rolls back textures',
      () {
        final checkBindings = saveBindings();
        cgl.failAt[entry.$1] = entry.$2;
        cgl.failDeletes = true;
        expectOriginalFailure(() => Framebuffer.defaultFramebuffer(cgl, 2, 2));
        checkBindings();
        expect(cgl.textures, hasLength(entry.$3));
        expect(cgl.framebuffers, isEmpty);
        expectReleased();
      },
    );
  }

  for (final withDepth in [false, true]) {
    test(
      'Zero-size framebuffer (depth=$withDepth) fails without assertions',
      () {
        final checkBindings = saveBindings();
        expect(
          () => withDepth
              ? Framebuffer.defaultFramebuffer(cgl, 0, 2)
              : Framebuffer.effect(cgl, 0, 2),
          throwsStateError,
        );
        checkBindings();
        expect(cgl.textures, hasLength(1));
        expectReleased();
      },
    );
  }

  for (final kind in ['mutable', 'image', 'cube']) {
    test('$kind texture constructor releases its partial upload', () {
      final source = web.HTMLCanvasElement()
        ..width = 2
        ..height = 2;
      final previous = gl.createTexture()!;
      final target = kind == 'cube' ? glTextureCubeMap : glTexture2D;
      gl.bindTexture(target, previous);
      cgl.failAt[kind == 'mutable' ? 'settings' : 'image'] = kind == 'cube'
          ? 3
          : 1;
      cgl.failDeletes = true;
      expectOriginalFailure(() {
        switch (kind) {
          case 'mutable':
            TypedTextureMutable(
              cgl,
              kind,
              2,
              2,
              glRgba,
              TextureProperties(),
              glRgba,
              glUnsignedByte,
              Uint8List(16),
            );
          case 'image':
            ImageTexture(cgl, kind, source);
          case 'cube':
            CubeTexture(cgl, kind, List<Object>.filled(6, source));
        }
      });
      expect(
        cgl.getParameter(
          kind == 'cube' ? glTextureBindingCubeMap : glTextureBinding2D,
        ),
        previous,
      );
      expect(gl.isTexture(previous), isTrue);
      expect(source.width, 2);
      expect(cgl.textures, hasLength(1));
      expectReleased();
    });
  }

  test(
    'A framebuffer can be constructed and rendered after a failed attempt',
    () {
      cgl.failAt['attachment'] = 1;
      expectOriginalFailure(() => Framebuffer.effect(cgl, 2, 2));
      final target = _Effect(cgl);
      cgl.clearColor(0, 1, 0, 1);
      target.activate(glColorBufferBit, 0, 0, 2, 2);
      expect(target.extractByteData(null, 0, 0, 2, 2), [
        for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
      ]);
      target.dispose();
      target.dispose();
      expectReleased();
    },
  );
}
