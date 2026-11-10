@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Count real WebGL calls as well as checking native handles: repeated deletion
// is accepted by WebGL, so isTexture/isProgram/isFramebuffer alone is not enough.
class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final programs = <GlProgram>[];
  final framebuffers = <GlFramebuffer>[];
  final deletedTextures = <GlTexture>[];
  final deletedPrograms = <GlProgram>[];
  final deletedFramebuffers = <GlFramebuffer>[];
  final deletedShaders = <GlShader>[];
  final deletionOrder = <String>[];
  final failures = <String, Object>{};
  void Function()? onDelete;
  int textureBinds = 0;
  int framebufferBinds = 0;
  int programUses = 0;

  @override
  GlProgram createProgram() {
    final program = super.createProgram();
    programs.add(program);
    return program;
  }

  @override
  GlFramebuffer createFramebuffer() {
    final framebuffer = super.createFramebuffer();
    framebuffers.add(framebuffer);
    return framebuffer;
  }

  void _afterDelete(String kind) {
    deletionOrder.add(kind);
    onDelete?.call();
    final failure = failures.remove(kind);
    if (failure != null) throw failure;
  }

  @override
  void deleteTexture(GlTexture texture) {
    deletedTextures.add(texture);
    super.deleteTexture(texture);
    _afterDelete('texture');
  }

  @override
  void deleteProgram(GlProgram program) {
    deletedPrograms.add(program);
    super.deleteProgram(program);
    _afterDelete('program');
  }

  @override
  void deleteFramebuffer(GlFramebuffer framebuffer) {
    deletedFramebuffers.add(framebuffer);
    super.deleteFramebuffer(framebuffer);
    _afterDelete('framebuffer');
  }

  @override
  void deleteShader(GlShader shader) {
    deletedShaders.add(shader);
    super.deleteShader(shader);
  }

  @override
  void bindTexture(int type, GlTexture? texture) {
    textureBinds++;
    super.bindTexture(type, texture);
  }

  @override
  void bindFramebuffer(int type, GlFramebuffer? framebuffer) {
    framebufferBinds++;
    super.bindFramebuffer(type, framebuffer);
  }

  @override
  void useProgram(GlProgram program) {
    programUses++;
    super.useProgram(program);
  }
}

void main() {
  late _TrackingGL cgl;
  late web.WebGL2RenderingContext gl;
  late web.HTMLCanvasElement canvas;

  setUp(() {
    canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = _TrackingGL(canvas);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
  });

  TypedTexture texture([int format = glRgba8]) => TypedTexture(
    cgl,
    'lifecycle',
    2,
    2,
    format,
    texturePropertiesFramebuffer,
  );

  TypedTextureMutable mutableTexture() => TypedTextureMutable(
    cgl,
    'mutable',
    2,
    2,
    glRgba,
    texturePropertiesFramebuffer,
    glRgba,
    glUnsignedByte,
    Uint8List(16),
  );

  RenderProgram program() {
    final vertex = ShaderObject('lifecycle-v')
      ..addAttributeVars([aPosition])
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('lifecycle-f')
      ..addUniformVars([uTexture])
      ..setBodyWithMain(['$oFragColor = texture($uTexture, vec2(0.5));']);
    return RenderProgram('lifecycle', cgl, vertex, fragment);
  }

  for (final kind in ['base', 'typed', 'mutable', 'image', 'cube']) {
    test(
      '$kind texture releases its handle once, including reentrant dispose',
      () {
        final source = web.HTMLCanvasElement()
          ..width = 2
          ..height = 2;
        final Texture tex = switch (kind) {
          'base' => Texture(cgl, glTexture2D, 'base', TextureProperties()),
          'typed' => texture(),
          'mutable' => mutableTexture(),
          'image' => ImageTexture(cgl, 'image', source),
          'cube' => CubeTexture(cgl, 'cube', List<Object>.filled(6, source)),
          _ => throw StateError(kind),
        };
        tex.install();
        final handle = tex.getTexture();
        expect(gl.isTexture(handle), isTrue);
        expect(tex.isDisposed, isFalse);
        cgl.onDelete = () {
          expect(tex.isDisposed, isTrue);
          expect(tex.getTexture, throwsStateError);
          tex.dispose();
        };
        tex.dispose();
        tex.dispose();
        expect(cgl.deletedTextures, [handle]);
        expect(gl.isTexture(handle), isFalse);
        expect(
          cgl.getParameter(
            kind == 'cube' ? glTextureBindingCubeMap : glTextureBinding2D,
          ),
          isNull,
        );
        expect(
          tex.getTextureType(),
          kind == 'cube' ? glTextureCubeMap : glTexture2D,
        );
        expect(
          tex.toString(),
          contains(
            kind == 'base'
                ? 'base'
                : kind == 'typed'
                ? 'lifecycle'
                : kind,
          ),
        );
        expect(source.width, 2);
        expect(source.height, 2);
        expect(cgl.getError(), glNoError);
      },
    );
  }

  test(
    'Disposed textures reject uploads and handle access before WebGL calls',
    () {
      final tex = mutableTexture()..dispose();
      final source = web.HTMLCanvasElement()
        ..width = 2
        ..height = 2;
      final image = ImageTexture(cgl, 'image', source)..dispose();
      final binds = cgl.textureBinds;
      for (final operation in <void Function()>[
        tex.getTexture,
        tex.install,
        () => tex.copyFromFramebuffer2D(0, 0, 2, 2),
        () => tex.updateContent(Uint8List(16), glRgba, glUnsignedByte),
        () => tex.updateContentPartial(
          Uint8List(4),
          glRgba,
          glUnsignedByte,
          0,
          0,
          1,
          1,
        ),
        image.update,
        () => image.setImageData(source),
      ]) {
        expect(
          operation,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('disposed'),
            ),
          ),
        );
      }
      expect(cgl.textureBinds, binds);
      expect(cgl.getError(), glNoError);
    },
  );

  test(
    'Image texture disposal preserves its borrowed DOM source and settings',
    () {
      final source = web.HTMLCanvasElement()
        ..width = 2
        ..height = 2;
      web.document.body!.append(source);
      addTearDown(() => source.remove());
      final properties = TextureProperties()..clamp = true;
      final first = ImageTexture(cgl, 'first', source, properties);
      final second = ImageTexture(cgl, 'second', source, properties);
      first.dispose();
      expect(source.isConnected, isTrue);
      expect(properties.clamp, isTrue);
      second.update();
      expect(gl.isTexture(second.getTexture()), isTrue);
      second.dispose();
      expect(cgl.getError(), glNoError);
    },
  );

  test('Texture stays disposed after a deletion error', () {
    final tex = texture();
    final handle = tex.getTexture();
    final failure = StateError('texture delete failure');
    cgl.failures['texture'] = failure;
    expect(tex.dispose, throwsA(same(failure)));
    tex.dispose();
    expect(tex.isDisposed, isTrue);
    expect(cgl.deletedTextures, [handle]);
    expect(gl.isTexture(handle), isFalse);
  });

  test(
    'Program releases temporary shaders after linking and its handle once',
    () {
      final prog = program();
      final handle = cgl.programs.single;
      expect(gl.isProgram(handle), isTrue);
      expect(prog.isDisposed, isFalse);
      expect(cgl.deletedShaders, hasLength(2));
      for (final shader in cgl.deletedShaders) {
        expect(gl.isShader(shader), isFalse);
      }
      expect(gl.getAttachedShaders(handle)!.toDart, isEmpty);
      cgl.onDelete = () {
        expect(prog.isDisposed, isTrue);
        prog.dispose();
      };
      prog.dispose();
      prog.dispose();
      expect(cgl.deletedPrograms, [handle]);
      expect(gl.isProgram(handle), isFalse);
      expect(cgl.getError(), glNoError);
    },
  );

  test('Current program disposal preserves shared mesh and sampler for another program', () {
    final first = program();
    final second = program();
    final tex = mutableTexture();
    final pixels = Uint8List.fromList([
      for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
    ]);
    tex.updateContent(pixels, glRgba, glUnsignedByte);
    final material = Material('shared')..setUniform(uTexture, tex);
    final md = first.makeMeshData('shared', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]));
    final target = Framebuffer.effect(cgl, 2, 2)
      ..activate(glColorBufferBit, 0, 0, 2, 2);
    cgl.disable(glDepthTest);
    first.draw(md, [material]);
    final handle = cgl.programs.first;
    first.dispose();
    expect(
      (gl.getProgramParameter(handle, glDeleteStatus) as JSBoolean).toDart,
      isTrue,
    );
    expect(gl.isProgram(handle), isTrue);
    expect(md.isDisposed, isFalse);
    expect(tex.isDisposed, isFalse);
    expect(first.hasCompatibleAttributesTo(second), isTrue);
    second.draw(md, [material]);
    expect(gl.isProgram(handle), isFalse);
    expect(target.extractByteData(null, 0, 0, 2, 2), pixels);
    expect(cgl.deletedTextures, isEmpty);
    second.dispose();
    gl.useProgram(null);
    target.dispose();
    md.dispose();
    tex.dispose();
    expect(cgl.getError(), glNoError);
  });

  test(
    'Disposed program rejects draw and mesh creation before touching WebGL',
    () {
      final prog = program();
      final md = prog.makeMeshData('mesh', glTriangles);
      prog.dispose();
      final uses = cgl.programUses;
      final stats = <DrawStats>[];
      expect(() => prog.draw(md, [], stats), throwsStateError);
      expect(() => prog.makeMeshData('new', glTriangles), throwsStateError);
      expect(prog.uninitializedInputs, throwsStateError);
      expect(cgl.programUses, uses);
      expect(stats, isEmpty);
      expect(prog.name, 'lifecycle');
      expect(prog.getContext(), same(cgl));
      md.dispose();
      expect(cgl.getError(), glNoError);
    },
  );

  test('Program stays disposed after a deletion error', () {
    final prog = program();
    final failure = StateError('program delete failure');
    cgl.failures['program'] = failure;
    expect(prog.dispose, throwsA(same(failure)));
    prog.dispose();
    expect(prog.isDisposed, isTrue);
    expect(cgl.deletedPrograms, cgl.programs);
    expect(gl.isProgram(cgl.programs.single), isFalse);
  });

  for (final withDepth in [false, true]) {
    test(
      'Factory framebuffer (depth=$withDepth) disposes its attachments once',
      () {
        final fb = withDepth
            ? Framebuffer.defaultFramebuffer(cgl, 2, 2)
            : Framebuffer.effect(cgl, 2, 2);
        final attachments = [?fb.colorTexture, ?fb.depthTexture];
        final handles = [for (final tex in attachments) tex.getTexture()];
        final handle = cgl.framebuffers.single;
        expect(fb.isDisposed, isFalse);
        expect(gl.isFramebuffer(handle), isTrue);
        fb.activate(glClearAll, 0, 0, 2, 2);
        cgl.onDelete = () {
          expect(fb.isDisposed, isTrue);
          expect(fb.colorTexture, isNull);
          expect(fb.depthTexture, isNull);
          fb.dispose();
        };
        fb.dispose();
        fb.dispose();
        for (final tex in attachments) {
          expect(tex.isDisposed, isTrue);
        }
        for (final tex in handles) {
          expect(gl.isTexture(tex), isFalse);
        }
        expect(gl.isFramebuffer(handle), isFalse);
        expect(cgl.getParameter(glFramebufferBinding), isNull);
        expect(cgl.deletedFramebuffers, [handle]);
        expect(cgl.deletedTextures, handles);
        expect(cgl.deletionOrder, [
          'framebuffer',
          for (final _ in handles) 'texture',
        ]);
        expect(cgl.getError(), glNoError);
      },
    );
  }

  test('Disposing framebuffer borrowers preserves shared color and depth-stencil attachments', () {
    final color = texture();
    final depthStencil = texture(glDepth24Stencil8);
    final first = Framebuffer(cgl, color, depthStencil, null, true);
    final second = Framebuffer(cgl, color, depthStencil, null, true);
    first.dispose();
    expect(cgl.deletedTextures, isEmpty);
    second.activate(glClearAll, 0, 0, 2, 2);
    expect(cgl.checkFramebufferStatus(glFramebuffer), glFramebufferComplete);
    expect(gl.isTexture(color.getTexture()), isTrue);
    expect(gl.isTexture(depthStencil.getTexture()), isTrue);
    second.dispose();
    expect(cgl.deletedTextures, isEmpty);
    color.dispose();
    depthStencil.dispose();
    expect(cgl.deletedFramebuffers, cgl.framebuffers);
    expect(cgl.getError(), glNoError);
  });

  test(
    'Attachment replacement releases owned textures and borrows new ones',
    () {
      final fb = Framebuffer.defaultFramebuffer(cgl, 2, 2);
      final owned = [fb.colorTexture!, fb.depthTexture!];
      final handles = [for (final tex in owned) tex.getTexture()];
      final external = texture();
      fb.colorTexture = external;
      fb.depthTexture = null;
      expect(cgl.deletedTextures, handles);
      fb.dispose();
      expect(cgl.deletedTextures, handles);
      for (final tex in owned) {
        expect(tex.isDisposed, isTrue);
      }
      expect(external.isDisposed, isFalse);
      expect(gl.isTexture(external.getTexture()), isTrue);
      external.dispose();
      expect(cgl.getError(), glNoError);
    },
  );

  test('Already disposed owned attachment is not deleted twice', () {
    final fb = Framebuffer.effect(cgl, 2, 2);
    final tex = fb.colorTexture!;
    final handle = tex.getTexture();
    tex.dispose();
    fb.dispose();
    expect(cgl.deletedTextures, [handle]);
    expect(cgl.getError(), glNoError);
  });

  for (final screen in [false, true]) {
    test(
      'Disposed framebuffer (screen=$screen) rejects activation and readback',
      () {
        final fb = screen
            ? Framebuffer.screen(cgl)
            : Framebuffer.effect(cgl, 2, 2);
        fb.dispose();
        fb.dispose();
        final bindings = cgl.framebufferBinds;
        expect(() => fb.activate(glClearAll, 0, 0, 2, 2), throwsStateError);
        expect(() => fb.extractByteData(null, 0, 0, 2, 2), throwsStateError);
        expect(() => fb.extractFloatData(null, 0, 0, 2, 2), throwsStateError);
        expect(cgl.framebufferBinds, bindings);
        if (screen) {
          expect(cgl.deletedFramebuffers, isEmpty);
          expect(cgl.deletedTextures, isEmpty);
          expect(gl.isContextLost(), isFalse);
          Framebuffer.screen(cgl)
            ..activate(glClearAll, 0, 0, 2, 2)
            ..dispose();
          expect(canvas.width, 2);
        }
        expect(cgl.getError(), glNoError);
      },
    );
  }

  test(
    'Framebuffer cleanup continues after errors and reports the first error',
    () {
      final fb = Framebuffer.defaultFramebuffer(cgl, 2, 2);
      final textures = [fb.colorTexture!, fb.depthTexture!];
      final handles = [for (final tex in textures) tex.getTexture()];
      final failure = StateError('framebuffer delete failure');
      cgl.failures['framebuffer'] = failure;
      cgl.failures['texture'] = StateError('texture delete failure');
      expect(fb.dispose, throwsA(same(failure)));
      fb.dispose();
      expect(fb.isDisposed, isTrue);
      expect(cgl.deletedFramebuffers, cgl.framebuffers);
      expect(cgl.deletedTextures, handles);
      for (final tex in textures) {
        expect(tex.isDisposed, isTrue);
      }
      for (final tex in handles) {
        expect(gl.isTexture(tex), isFalse);
      }
      expect(gl.isFramebuffer(cgl.framebuffers.single), isFalse);
      expect(cgl.getError(), glNoError);
    },
  );

  test('All wrappers can be disposed after losing their WebGL context', () {
    final fb = Framebuffer.defaultFramebuffer(cgl, 2, 2);
    final prog = program();
    final tex = texture();
    final extension =
        cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?;
    expect(extension, isNotNull);
    extension!.loseContext();
    expect(gl.isContextLost(), isTrue);
    for (var i = 0; i < 2; i++) {
      fb.dispose();
      prog.dispose();
      tex.dispose();
    }
    expect(fb.isDisposed, isTrue);
    expect(prog.isDisposed, isTrue);
    expect(tex.isDisposed, isTrue);
    expect(cgl.deletedFramebuffers, hasLength(1));
    expect(cgl.deletedPrograms, hasLength(1));
    expect(cgl.deletedTextures, hasLength(3));
  });
}
