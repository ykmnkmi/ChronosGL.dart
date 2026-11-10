@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Instrument real WebGL calls: isBuffer/isVertexArray alone cannot distinguish
// one deletion from repeated deletion, since WebGL accepts both.
class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final buffers = <GlBuffer>[];
  final deletedBuffers = <GlBuffer>[];
  final vaos = <GlVertexArrayObject>[];
  final deletedVaos = <GlVertexArrayObject>[];
  final deletionOrder = <String>[];
  bool failVertexArrayCreation = false;
  Object? deletionFailure;
  int programUses = 0;
  void Function()? onDelete;

  @override
  GlBuffer createBuffer() {
    final buffer = super.createBuffer();
    buffers.add(buffer);
    return buffer;
  }

  @override
  GlVertexArrayObject createVertexArray() {
    if (failVertexArrayCreation) throw StateError('VAO creation failed');
    final vao = super.createVertexArray();
    vaos.add(vao);
    return vao;
  }

  @override
  void deleteBuffer(GlBuffer buffer) {
    onDelete?.call();
    deletedBuffers.add(buffer);
    deletionOrder.add('buffer');
    super.deleteBuffer(buffer);
    final failure = deletionFailure;
    deletionFailure = null;
    if (failure != null) throw failure;
  }

  @override
  void deleteVertexArray(GlVertexArrayObject vao) {
    onDelete?.call();
    deletedVaos.add(vao);
    deletionOrder.add('vao');
    super.deleteVertexArray(vao);
  }

  @override
  void useProgram(GlProgram program) {
    programUses++;
    super.useProgram(program);
  }
}

Float32List _vertices() =>
    Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]);

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

  MeshData mesh() => MeshData('lifecycle', cgl, glTriangles, {
    aPosition: 0,
    aNormal: 1,
    iaTranslation: 2,
  });

  void expectAllDeleted() {
    expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
    expect(cgl.deletedVaos, orderedEquals(cgl.vaos));
    for (final buffer in cgl.buffers) {
      expect(gl.isBuffer(buffer), isFalse);
    }
    for (final vao in cgl.vaos) {
      expect(gl.isVertexArray(vao), isFalse);
    }
    expect(cgl.getError(), glNoError);
  }

  RenderProgram program() {
    final vertex = ShaderObject('disposal-v')
      ..addAttributeVars([aPosition])
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('disposal-f')
      ..setBodyWithMain(['$oFragColor = vec4(0.0, 1.0, 0.0, 1.0);']);
    return RenderProgram('disposal', cgl, vertex, fragment);
  }

  test('Disposes an empty mesh and its VAO exactly once', () {
    final md = mesh();
    expect(md.isDisposed, isFalse);
    expect(md.getNumItems(), 0);
    md.activate();
    expect(gl.isVertexArray(cgl.vaos.single), isTrue);
    md.dispose();
    md.dispose();
    expect(md.isDisposed, isTrue);
    expect(cgl.getParameter(glVertexArrayBinding), isNull);
    expectAllDeleted();
  });

  test('Disposes indexed and instanced mesh resources once, VAO first', () {
    final vertices = _vertices();
    final md = mesh()
      ..addVertices(vertices)
      ..addAttribute(aNormal, Float32List(9), 3)
      ..addAttribute(iaTranslation, Float32List(6), 3)
      ..addFaces([0, 1, 2]);
    final attributes = md.getAttributes();
    for (final buffer in cgl.buffers) {
      expect(gl.isBuffer(buffer), isTrue);
    }
    expect(md.getNumInstances(), 2);
    cgl.onDelete = () {
      expect(md.isDisposed, isTrue);
      md.dispose(); // Reentrant cleanup must not delete the same handle again.
    };
    md.dispose();
    md.dispose();
    expect(attributes, isEmpty);
    expect(vertices, _vertices());
    expect(cgl.deletionOrder, ['vao', 'buffer', 'buffer', 'buffer', 'buffer']);
    expectAllDeleted();
  });

  test('Releases replaced owned buffers before final cleanup', () {
    final md = mesh()..addVertices(_vertices());
    md.addAttribute(aNormal, Float32List(9), 3);
    md.addFaces([0, 1, 2]);
    md.addVertices(_vertices());
    md.addAttribute(aNormal, Float32List(9), 3);
    md.addFaces([2, 1, 0]);
    expect(cgl.buffers, hasLength(6));
    expect(cgl.deletedBuffers, cgl.buffers.take(3));
    md.dispose();
    md.dispose();
    expectAllDeleted();
  });

  test('An owned buffer aliased in multiple attributes is deleted once', () {
    final md = mesh()..addVertices(_vertices());
    // Obtain another JS interop reference to the same native buffer.
    final alias = gl.getParameter(glArrayBufferBinding) as GlBuffer;
    md.changeAttributeBuffer(aNormal, alias);
    md.changeAttributeBuffer(aPosition, alias);
    md.addVertices(_vertices());
    expect(gl.isBuffer(alias), isTrue);
    md.dispose();
    expect(cgl.buffers, hasLength(2));
    expectAllDeleted();
  });

  test('Disposing borrowers preserves the shared buffer and its owner', () {
    final owner = mesh()..addVertices(_vertices());
    final shared = owner.getBuffer(aPosition);
    final first = mesh()
      ..addVertices(_vertices())
      ..changeAttributeBuffer(aPosition, shared);
    final second = mesh()
      ..addVertices(_vertices())
      ..changeAttributeBuffer(aPosition, shared);
    first.dispose();
    expect(gl.isBuffer(shared), isTrue);
    second.activate();
    expect(gl.getVertexAttrib(0, glVertexAttribArrayBufferBinding), shared);
    second.clearData();
    second.dispose();
    expect(gl.isBuffer(shared), isTrue);
    expect(cgl.deletedBuffers, isNot(contains(shared)));
    owner.dispose();
    expect(gl.isBuffer(shared), isFalse);
    expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
    expect(cgl.deletedVaos, unorderedEquals(cgl.vaos));
    expect(cgl.getError(), glNoError);
  });

  test('clearData resets VAO bindings, CPU data and counts for reuse', () {
    final md = mesh()
      ..addVertices(_vertices())
      ..addAttribute(iaTranslation, Float32List(6), 3)
      ..addFaces([0, 1, 2]);
    final oldVao = cgl.vaos.single;
    md.clearData();
    expect(md.isDisposed, isFalse);
    expect(md.getNumItems(), 0);
    expect(md.getNumInstances(), 0);
    expect(md.elementArrayBufferType, -1);
    expect(md.getAttributes(), isEmpty);
    expect(gl.isVertexArray(oldVao), isFalse);
    expect(cgl.deletedBuffers, orderedEquals(cgl.buffers));
    md.activate();
    expect(cgl.getParameter(glElementArrayBufferBinding), isNull);
    for (final index in [0, 1, 2]) {
      expect(
        gl.getVertexAttrib(index, glVertexAttribArrayBufferBinding),
        isNull,
      );
      expect(
        (gl.getVertexAttrib(
          index,
          glVertexAttribArrayEnabled,
        ) as JSBoolean).toDart,
        isFalse,
      );
    }
    md.clearData();
    md.addVertices(_vertices());
    md.addFaces([0, 1, 2]);
    expect(md.getNumItems(), 3);
    md.dispose();
    expectAllDeleted();
  });

  test('A mesh can render again after clearData', () {
    final prog = program();
    final md = prog.makeMeshData('reusable', glTriangles)
      ..addVertices(_vertices())
      ..addFaces([0, 1, 2]);
    cgl.viewport(0, 0, 2, 2);
    cgl.disable(glDepthTest);
    cgl.disable(glDither);
    for (var pass = 0; pass < 2; pass++) {
      cgl.clearColor(0, 0, 0, 1);
      cgl.clear(glColorBufferBit);
      prog.draw(md, []);
      final pixels = Uint8List(16);
      cgl.readPixels(0, 0, 2, 2, glRgba, glUnsignedByte, pixels);
      expect(pixels, [
        for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
      ]);
      if (pass == 0) {
        md.clearData();
        md.addVertices(_vertices()); // Non-indexed reuse must use drawArrays.
      }
    }
    md.dispose();
    expectAllDeleted();
  });

  test('Failed VAO replacement leaves existing mesh intact', () {
    final md = mesh()
      ..addVertices(_vertices())
      ..addFaces([0, 1, 2]);
    final buffer = md.getBuffer(aPosition);
    cgl.failVertexArrayCreation = true;
    expect(md.clearData, throwsStateError);
    expect(md.isDisposed, isFalse);
    expect(md.getBuffer(aPosition), buffer);
    expect(md.getNumItems(), 3);
    md.activate();
    expect(cgl.deletedVaos, isEmpty);
    expect(cgl.deletedBuffers, isEmpty);
    md.dispose();
    expectAllDeleted();
  });

  test('Cleanup continues after deletion throws and cannot run twice', () {
    final md = mesh()
      ..addVertices(_vertices())
      ..addAttribute(aNormal, Float32List(9), 3)
      ..addFaces([0, 1, 2]);
    final failure = StateError('injected deletion failure');
    cgl.deletionFailure = failure;
    expect(md.dispose, throwsA(same(failure)));
    expect(md.isDisposed, isTrue);
    md.dispose();
    expectAllDeleted();
  });

  test('A partially populated mesh can be disposed without losing buffers', () {
    final md = mesh()..addVertices(_vertices());
    // An unsupported attribute is rejected before buffer allocation.
    expect(() => md.addAttribute(aColor, Float32List(9), 3), throwsA(anything));
    expect(cgl.buffers, hasLength(1));
    md.dispose();
    expectAllDeleted();
  });

  test('Disposed meshes reject data access and GPU use before any GL work', () {
    final prog = program();
    final md = mesh()..addVertices(_vertices());
    final buffer = md.getBuffer(aPosition);
    md.dispose();
    final operations = <void Function()>[
      md.clearData,
      md.activate,
      () => md.addVertices(_vertices()),
      () => md.addAttribute(aNormal, Float32List(9), 3),
      () => md.addFaces([0, 1, 2]),
      () => md.changeVertexData(_vertices()),
      () => md.changeAttributeData(aNormal, Float32List(9), 3),
      () => md.changeAttributeBuffer(aPosition, buffer),
      () => md.changeFaces([0, 1, 2]),
      () => md.getBuffer(aPosition),
      () => md.getAttribute(aPosition),
      () => md.getAttributes(),
      () => md.getNumItems(),
      () => md.getNumInstances(),
      () => md.elementArrayBufferType,
      () => prog.draw(md, []),
    ];
    for (final operation in operations) {
      expect(
        operation,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(md.name),
          ),
        ),
      );
    }
    expect(md.name, contains('lifecycle'));
    expect(md.drawMode, glTriangles);
    expect(md.supportsAttribute(aPosition), isTrue);
    expect(md.toString(), contains(md.name));
    expect(cgl.programUses, 0);
    expect(cgl.buffers, hasLength(1));
    expect(cgl.vaos, hasLength(1));
    expect(cgl.getParameter(glVertexArrayBinding), isNull);
    expectAllDeleted();
  });

  test('Disposal remains safe after context loss', () {
    final md = mesh()
      ..addVertices(_vertices())
      ..addFaces([0, 1, 2]);
    final extension =
        cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context;
    extension.loseContext();
    md.dispose();
    md.dispose();
    expect(md.isDisposed, isTrue);
    expect(cgl.deletedBuffers, orderedEquals(cgl.buffers));
    expect(cgl.deletedVaos, orderedEquals(cgl.vaos));
  });
}
