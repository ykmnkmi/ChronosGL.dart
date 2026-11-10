@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Track entry into the GL paths involved in validation, drawing, framebuffer
// use and mesh creation. Even a query or a temporary allocation is observable.
class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final calls = <String>[];

  @override
  Object? getParameter(int kind) {
    calls.add('getParameter');
    return super.getParameter(kind);
  }

  @override
  GlVertexArrayObject createVertexArray() {
    calls.add('createVertexArray');
    return super.createVertexArray();
  }

  @override
  GlFramebuffer createFramebuffer() {
    calls.add('createFramebuffer');
    return super.createFramebuffer();
  }

  @override
  void bindFramebuffer(int type, GlFramebuffer? framebuffer) {
    calls.add('bindFramebuffer');
    super.bindFramebuffer(type, framebuffer);
  }

  @override
  void bindTexture(int type, GlTexture? texture) {
    calls.add('bindTexture');
    super.bindTexture(type, texture);
  }

  @override
  void activeTexture(int target) {
    calls.add('activeTexture');
    super.activeTexture(target);
  }

  @override
  void useProgram(GlProgram program) {
    calls.add('useProgram');
    super.useProgram(program);
  }

  @override
  void viewport(int x, int y, int w, int h) {
    calls.add('viewport');
    super.viewport(x, y, w, h);
  }

  @override
  void clear(int mode) {
    calls.add('clear');
    super.clear(mode);
  }

  @override
  void readPixels(
    int x,
    int y,
    int w,
    int h,
    int format,
    int type,
    TypedData buf,
  ) {
    calls.add('readPixels');
    super.readPixels(x, y, w, h, format, type, buf);
  }
}

class _CountingUniforms extends UniformGroup {
  _CountingUniforms() : super('on-demand');

  int reads = 0;

  @override
  Map<String, Object> getUniforms() {
    reads++;
    return super.getUniforms();
  }
}

Matcher _disposed(String identity) => throwsA(
  isA<StateError>().having(
    (error) => error.message,
    'message',
    allOf(contains(identity), contains('disposed')),
  ),
);

void main() {
  late _TrackingGL cgl;

  setUp(() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = _TrackingGL(canvas);
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
  });

  RenderProgram program({
    List<String> samplers = const [],
    String expression = 'vec4(1.0)',
  }) {
    final vertex = ShaderObject('usage-v')
      ..addAttributeVars([aPosition])
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('usage-f')
      ..addUniformVars(samplers)
      ..setBodyWithMain(['$oFragColor = $expression;']);
    final result = RenderProgram('usage-program', cgl, vertex, fragment);
    addTearDown(result.dispose);
    return result;
  }

  MeshData mesh(RenderProgram prog, {int mode = glTriangles}) {
    final result = prog.makeMeshData('usage-mesh', mode)
      ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]))
      ..addFaces([0, 1, 2]);
    addTearDown(result.dispose);
    return result;
  }

  TypedTexture texture(String name, [int format = glRgba8]) {
    final result = TypedTexture(
      cgl,
      name,
      2,
      2,
      format,
      texturePropertiesFramebuffer,
    );
    addTearDown(result.dispose);
    return result;
  }

  final helpers = <String, void Function(RenderProgram, MeshData)>{
    'extractWireframeNormals': (p, m) => extractWireframeNormals(p, m),
    'extractWireframe': (p, m) => extractWireframe(p, m),
    'extractPointCloud': (p, m) => extractPointCloud(p, m, 1),
    'getMeshFaceArea': (_, m) => getMeshFaceArea(m),
  };
  for (final entry in helpers.entries) {
    test('${entry.key} rejects disposed mesh before assertions/allocation', () {
      final prog = program();
      // Deliberately incompatible mode: lifecycle errors take precedence.
      final md = mesh(prog, mode: glPoints)..dispose();
      cgl.calls.clear();
      expect(() => entry.value(prog, md), _disposed('MeshData ${md.name}'));
      expect(cgl.calls, isEmpty);
    });
    if (entry.key == 'getMeshFaceArea') continue;
    test('${entry.key} rejects disposed program before reading mesh data', () {
      final prog = program();
      final md = mesh(prog, mode: glPoints);
      prog.dispose();
      cgl.calls.clear();
      expect(
        () => entry.value(prog, md),
        _disposed('RenderProgram ${prog.name}'),
      );
      expect(cgl.calls, isEmpty);
      expect(md.getNumItems(), 3);
    });
  }

  test('Diagnostic metadata remains available after disposal', () {
    final prog = program();
    final other = program();
    final md = mesh(prog);
    final tex = texture('metadata');
    final target = Framebuffer(cgl, tex);
    md.dispose();
    prog.dispose();
    other.dispose();
    tex.dispose();
    target.dispose();
    cgl.calls.clear();

    expect(md.name, 'meshdata:usage-mesh');
    expect(md.drawMode, glTriangles);
    expect(md.supportsAttribute(aPosition), isTrue);
    expect(md.toString(), contains(md.name));
    expect(prog.getContext(), same(cgl));
    expect(prog.shaderObjectV.attributeVars, contains(aPosition));
    expect(prog.shaderObjectF.uniformVars, isEmpty);
    expect(prog.getTransformBindingIndex('missing'), -1);
    expect(prog.hasCompatibleAttributesTo(other), isTrue);
    expect(prog.hasDownwardCompatibleAttributesTo(other), isTrue);
    expect(tex.getTextureType(), glTexture2D);
    expect(tex.properties, same(texturePropertiesFramebuffer));
    expect(tex.toString(), contains('metadata'));
    expect([
      target.colorTexture,
      target.depthTexture,
      target.stencilTexture,
    ], everyElement(isNull));
    expect(cgl.calls, isEmpty);
  });

  for (final kind in ['program', 'mesh']) {
    test('Disposed $kind rejects draw before evaluating uniform groups', () {
      final prog = program();
      final md = mesh(prog);
      final uniforms = _CountingUniforms();
      final stats = <DrawStats>[];
      if (kind == 'program') {
        prog.dispose();
      } else {
        md.dispose();
      }
      cgl.calls.clear();
      expect(
        () => prog.draw(md, [uniforms], stats),
        _disposed(kind == 'program' ? prog.name : md.name),
      );
      expect(uniforms.reads, 0);
      expect(stats, isEmpty);
      expect(cgl.calls, isEmpty);
    });
  }

  for (final sampler in [uTexture, uShadowMap, uCubeTexture]) {
    test('Draw rejects disposed $sampler before any GL call', () {
      final expression = switch (sampler) {
        uShadowMap => 'vec4(texture($sampler, vec3(0.5)))',
        uCubeTexture => 'texture($sampler, vec3(1.0, 0.0, 0.0))',
        _ => 'texture($sampler, vec2(0.5))',
      };
      final prog = program(samplers: [sampler], expression: expression);
      final md = mesh(prog);
      final tex = texture('dead-sampler')..dispose();
      final uniforms = _CountingUniforms()..setUniform(sampler, tex);
      final stats = <DrawStats>[];
      final before = prog.uninitializedInputs();
      cgl.calls.clear();
      expect(
        () => prog.draw(md, [uniforms], stats),
        _disposed('Texture dead-sampler'),
      );
      expect(uniforms.reads, 1);
      expect(stats, isEmpty);
      expect(prog.uninitializedInputs(), before);
      expect(cgl.calls, isEmpty);
    });
  }

  test('All uniform groups are checked before upload; next draw recovers', () {
    final prog = program(
      samplers: [uTexture, uTexture2],
      expression:
          'texture($uTexture, vec2(0.5)) + texture($uTexture2, vec2(0.5))',
    );
    final md = mesh(prog);
    final target = Framebuffer.effect(cgl, 2, 2);
    addTearDown(target.dispose);
    cgl.clearColor(0, 1, 0, 1);
    target.activate(glColorBufferBit, 0, 0, 2, 2);
    final live = target.colorTexture!;
    final dead = texture('later-group')..dispose();
    final first = _CountingUniforms()..setUniform(uTexture, live);
    final second = _CountingUniforms()..setUniform(uTexture2, dead);
    final uniforms = List<UniformGroup>.unmodifiable([first, second]);
    final screen = Framebuffer.screen(cgl)..activate(0, 0, 0, 2, 2);
    addTearDown(screen.dispose);
    final stats = <DrawStats>[];
    cgl.calls.clear();
    expect(
      () => prog.draw(md, uniforms, stats),
      _disposed('Texture later-group'),
    );
    expect(cgl.calls, isEmpty);
    expect(stats, isEmpty);
    second.forceUniform(uTexture2, live);
    prog.draw(md, uniforms, stats);
    expect([first.reads, second.reads], [2, 2]);
    expect(stats, hasLength(1));
    expect(prog.uninitializedInputs(), isEmpty);
    expect(screen.extractByteData(null, 0, 0, 2, 2), [
      for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
    ]);
    expect(cgl.getError(), glNoError);
  });

  test('Optimized-out samplers may still refer to disposed textures', () {
    final prog = program(samplers: [uTexture]);
    final md = mesh(prog);
    final tex = texture('unused')..dispose();
    final uniforms = _CountingUniforms()..setUniform(uTexture, tex);
    cgl.viewport(0, 0, 2, 2);
    prog.draw(md, [uniforms]);
    expect(uniforms.reads, 1);
    expect(prog.uninitializedInputs(), isEmpty);
    expect(cgl.getError(), glNoError);
  });

  for (final slot in ['color', 'depth', 'depth-stencil']) {
    test('Framebuffer rejects dead $slot attachment before activation/readback', () {
      final color = texture('color');
      final depth = texture(
        'depth',
        slot == 'depth-stencil' ? glDepth24Stencil8 : glDepthComponent24,
      );
      final target = Framebuffer(
        cgl,
        color,
        depth,
        null,
        slot == 'depth-stencil',
      );
      addTearDown(target.dispose);
      final dead = slot == 'color' ? color : depth;
      dead.dispose();
      final bytes = Uint8List(16)..fillRange(0, 16, 17);
      final floats = Float32List(16)..fillRange(0, 16, 19);
      final operations = <void Function()>[
        () => target.activate(glClearAll, 0, 0, 2, 2),
        () => target.extractByteData(bytes, 0, 0, 2, 2),
        () => target.extractFloatData(floats, 0, 0, 2, 2),
      ];
      cgl.calls.clear();
      for (final operation in operations) {
        expect(
          operation,
          _disposed('Texture ${slot == 'color' ? 'color' : 'depth'}'),
        );
      }
      expect(cgl.calls, isEmpty);
      expect(bytes, everyElement(17));
      expect(floats, everyElement(19));
      expect(target.isDisposed, isFalse);
      // A live container can recover by explicitly replacing dead attachments.
      target.replaceAttachments(colorTexture: texture('replacement'));
      target.activate(glColorBufferBit, 0, 0, 2, 2);
      expect(cgl.getError(), glNoError);
    });
  }

  test(
    'Framebuffer creation rejects disposed attachments before GL queries',
    () {
      final dead = texture('constructor')..dispose();
      cgl.calls.clear();
      expect(() => Framebuffer(cgl, dead), _disposed('Texture constructor'));
      expect(
        () => Framebuffer.withAttachments(
          cgl,
          colorTexture: dead,
          takeOwnership: [dead],
        ),
        _disposed('Texture constructor'),
      );
      expect(cgl.calls, isEmpty);
    },
  );

  test(
    'Framebuffer replacement rejects disposed attachments before GL queries',
    () {
      final target = Framebuffer.effect(cgl, 2, 2);
      addTearDown(target.dispose);
      final original = target.colorTexture;
      final dead = texture('replacement')..dispose();
      cgl.calls.clear();
      for (final replace in <void Function()>[
        () => target.colorTexture = dead,
        () => target.depthTexture = dead,
        () => target.stencilTexture = dead,
        () => target.replaceAttachments(
          colorTexture: dead,
          takeOwnership: [dead],
        ),
      ]) {
        expect(replace, _disposed('Texture replacement'));
      }
      expect(cgl.calls, isEmpty);
      expect(target.colorTexture, same(original));
      expect(original!.isDisposed, isFalse);
    },
  );

  for (final screen in [false, true]) {
    test(
      'Disposed framebuffer (screen=$screen) rejects every replacement API',
      () {
        final target = screen
            ? Framebuffer.screen(cgl)
            : Framebuffer.effect(cgl, 2, 2);
        target.dispose();
        cgl.calls.clear();
        for (final replace in <void Function()>[
          () => target.colorTexture = null,
          () => target.depthTexture = null,
          () => target.stencilTexture = null,
          target.replaceAttachments,
        ]) {
          expect(replace, _disposed('Framebuffer'));
        }
        expect(cgl.calls, isEmpty);
      },
    );
  }
}
