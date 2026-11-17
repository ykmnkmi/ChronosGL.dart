@TestOn('chrome')
library;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final buffers = <GlBuffer>[];
  final deletedBuffers = <GlBuffer>[];
  final vaos = <GlVertexArrayObject>[];
  final deletedVaos = <GlVertexArrayObject>[];
  final programs = <GlProgram>[];
  final deletedPrograms = <GlProgram>[];
  int? failBufferNumber;
  bool failVaoDeletion = false;
  final failure = StateError('injected fullscreen resource failure');

  @override
  GlBuffer createBuffer() {
    if (buffers.length + 1 == failBufferNumber) throw failure;
    final handle = super.createBuffer();
    buffers.add(handle);
    return handle;
  }

  @override
  void deleteBuffer(GlBuffer handle) {
    deletedBuffers.add(handle);
    super.deleteBuffer(handle);
  }

  @override
  GlVertexArrayObject createVertexArray() {
    final handle = super.createVertexArray();
    vaos.add(handle);
    return handle;
  }

  @override
  void deleteVertexArray(GlVertexArrayObject handle) {
    deletedVaos.add(handle);
    super.deleteVertexArray(handle);
    if (failVaoDeletion) throw failure;
  }

  @override
  GlProgram createProgram() {
    final handle = super.createProgram();
    programs.add(handle);
    return handle;
  }

  @override
  void deleteProgram(GlProgram handle) {
    deletedPrograms.add(handle);
    super.deleteProgram(handle);
  }
}

class _ThrowingUniforms extends UniformGroup {
  _ThrowingUniforms() : super('throwing');

  @override
  Map<String, Object> getUniforms() => throw StateError('uniform read failed');
}

RenderProgram _program(ChronosGL cgl, {bool texture = false}) {
  final vertex = ShaderObject('fullscreen-v')
    ..addAttributeVars([aPosition, aTexUV])
    ..addVaryingVars([vTexUV])
    ..setBodyWithMain([
      'gl_Position = vec4($aPosition, 1.0);',
      '$vTexUV = $aTexUV;',
    ]);
  final fragment = ShaderObject('fullscreen-f')
    ..addVaryingVars([vTexUV])
    ..addUniformVars([if (texture) uTexture])
    ..setBodyWithMain([
      texture
          ? '$oFragColor = texture($uTexture, $vTexUV);'
          : '$oFragColor = vec4($vTexUV, 0.0, 1.0);',
    ]);
  return RenderProgram('fullscreen', cgl, vertex, fragment);
}

void main() {
  late _TrackingGL cgl;
  late web.WebGL2RenderingContext gl;

  setUp(() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = _TrackingGL(canvas);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
  });

  test(
    'Fullscreen quad covers the viewport and recovers after uniform errors',
    () {
      final program = _program(cgl);
      addTearDown(program.dispose);
      final pass = FullscreenPass(program);
      addTearDown(pass.dispose);
      final screen = Framebuffer.screen(cgl);
      final groups = List<UniformGroup>.unmodifiable([UniformGroup('input')]);
      final before = Map<String, Object>.of(groups.single.getUniforms());
      screen.activate(glClearAll, 0, 0, 2, 2);

      expect(() => pass.draw([_ThrowingUniforms()]), throwsStateError);
      pass.draw(groups);

      expect(groups, hasLength(1));
      expect(groups.single.getUniforms(), before);
      final pixels = screen.extractByteData(null, 0, 0, 2, 2);
      for (var i = 0; i < 4; i++) {
        expect(pixels[i * 4], closeTo(i.isEven ? 64 : 191, 1));
        expect(pixels[i * 4 + 1], closeTo(i < 2 ? 64 : 191, 1));
        expect(pixels.sublist(i * 4 + 2, i * 4 + 4), [0, 255]);
      }
      expect(cgl.getError(), glNoError);
    },
  );

  test('Passes own independent meshes and default materials', () {
    final program = _program(cgl);
    addTearDown(program.dispose);
    final first = FullscreenPass(program);
    final second = FullscreenPass(program);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    expect(first.meshData, isNot(same(second.meshData)));
    expect(first.material, isNot(same(second.material)));
    first.material.forceUniform(cDepthWrite, true);
    expect(second.material.getUniforms()[cDepthWrite], isFalse);
    expect(second.material.getUniforms()[cDepthTest], isFalse);

    first.dispose();
    first.dispose();
    expect(first.isDisposed, isTrue);
    expect(first.meshData.isDisposed, isTrue);
    expect(program.isDisposed, isFalse);
    expect(() => first.draw(), throwsStateError);
    Framebuffer.screen(cgl).activate(glClearAll, 0, 0, 2, 2);
    second.draw();
    expect(cgl.getError(), glNoError);
  });

  test(
    'Borrowed material, texture and replacement node mesh survive disposal',
    () {
      final program = _program(cgl, texture: true);
      addTearDown(program.dispose);
      final texture = TypedTexture(
        cgl,
        'borrowed texture',
        1,
        1,
        glRgba8,
        texturePropertiesFramebuffer,
      );
      addTearDown(texture.dispose);
      final material = Material('borrowed')..setUniform(uTexture, texture);
      final snapshot = Map<String, Object>.of(material.getUniforms());
      final pass = FullscreenPass(program, material: material);
      final mesh = pass.meshData;
      final replacement = program.makeGpuMesh('replacement', glTriangles);
      addTearDown(replacement.dispose);
      pass.node.mesh = replacement;
      pass.dispose();

      expect(pass.material, same(material));
      expect(material.getUniforms(), snapshot);
      expect(mesh.isDisposed, isTrue);
      expect(replacement.isDisposed, isFalse);
      expect(texture.isDisposed, isFalse);
      expect(gl.isTexture(texture.getTexture()), isTrue);
    },
  );

  for (final ownsProgram in [false, true]) {
    test('Failed upload cleans resources (ownsProgram=$ownsProgram)', () {
      final program = _program(cgl);
      addTearDown(program.dispose);
      cgl.failBufferNumber = 2;
      cgl.failVaoDeletion = true;

      expect(
        () => FullscreenPass(program, ownsProgram: ownsProgram),
        throwsA(same(cgl.failure)),
      );

      expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
      expect(cgl.deletedVaos, unorderedEquals(cgl.vaos));
      expect(program.isDisposed, ownsProgram);
      for (final buffer in cgl.buffers) {
        expect(gl.isBuffer(buffer), isFalse);
      }
      for (final vao in cgl.vaos) {
        expect(gl.isVertexArray(vao), isFalse);
      }
    });
  }

  test('Disposal attempts owned program cleanup after mesh cleanup throws', () {
    final program = _program(cgl);
    final pass = FullscreenPass(program, ownsProgram: true);
    cgl.failVaoDeletion = true;

    expect(pass.dispose, throwsA(same(cgl.failure)));
    pass.dispose();

    expect(pass.isDisposed, isTrue);
    expect(pass.meshData.isDisposed, isTrue);
    expect(program.isDisposed, isTrue);
    expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
    expect(cgl.deletedVaos, unorderedEquals(cgl.vaos));
    expect(cgl.deletedPrograms, unorderedEquals(cgl.programs));
    for (final program in cgl.programs) {
      expect(gl.isProgram(program), isFalse);
    }
  });
}
