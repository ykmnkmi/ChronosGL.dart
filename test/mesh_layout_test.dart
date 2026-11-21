@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/geometry.dart' as cpu;
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final buffers = <GlBuffer>[];
  final deletedBuffers = <GlBuffer>[];
  final vaos = <GlVertexArrayObject>[];
  final deletedVaos = <GlVertexArrayObject>[];
  int activations = 0;
  int? failBufferNumber;
  final failure = StateError('injected upload failure');

  @override
  GlBuffer createBuffer() {
    if (buffers.length + 1 == failBufferNumber) throw failure;
    final buffer = super.createBuffer();
    buffers.add(buffer);
    return buffer;
  }

  @override
  void deleteBuffer(GlBuffer buffer) {
    deletedBuffers.add(buffer);
    super.deleteBuffer(buffer);
  }

  @override
  GlVertexArrayObject createVertexArray() {
    final vao = super.createVertexArray();
    vaos.add(vao);
    return vao;
  }

  @override
  void deleteVertexArray(GlVertexArrayObject vao) {
    deletedVaos.add(vao);
    super.deleteVertexArray(vao);
  }

  @override
  void useProgram(GlProgram program) {
    activations++;
    super.useProgram(program);
  }
}

class _CountingUniforms extends UniformGroup {
  _CountingUniforms() : super('counting');
  int reads = 0;

  @override
  Map<String, Object> getUniforms() {
    reads++;
    return super.getUniforms();
  }
}

void main() {
  late _TrackingGL cgl;

  _TrackingGL context() {
    final result = _TrackingGL(
      web.HTMLCanvasElement()
        ..width = 2
        ..height = 2,
    );
    addTearDown(() {
      (result.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    return result;
  }

  setUp(() => cgl = context());

  RenderProgram program(List<String> attributes, {ChronosGL? gl}) {
    final vertex = ShaderObject('layout-v')
      ..addAttributeVars(attributes)
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('layout-f')
      ..setBodyWithMain(['$oFragColor = vec4(0.0, 1.0, 0.0, 1.0);']);
    final result = RenderProgram('layout', gl ?? cgl, vertex, fragment);
    addTearDown(result.dispose);
    return result;
  }

  GpuMesh mesh(RenderProgram prog) {
    final result = prog.makeGpuMesh('triangle', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]));
    addTearDown(result.dispose);
    return result;
  }

  test('MeshData compatibility constructor snapshots immutable bindings', () {
    final locations = {aPosition: 0, iaTranslation: 1};
    final MeshData legacy = MeshData('legacy', cgl, glTriangles, locations);
    final GpuMesh gpu = legacy;
    addTearDown(gpu.dispose);
    locations[aPosition] = 7;
    locations.clear();
    expect(gpu.supportsAttribute(aPosition), isTrue);
    final attributes = gpu.attributeLayout.attributes;
    expect(attributes[aPosition]!.location, 0);
    expect(attributes[aPosition]!.type, varTypeVec3);
    expect(attributes[aPosition]!.width, 3);
    expect(attributes[aPosition]!.divisor, 0);
    expect(attributes[iaTranslation]!.divisor, 1);
    expect(() => attributes.clear(), throwsUnsupportedError);
  });

  test('Invalid layouts fail before VAO allocation', () {
    final count = cgl.vaos.length;
    expect(
      () => GpuMesh('duplicate', cgl, glTriangles, {aPosition: 0, aColor: 0}),
      throwsArgumentError,
    );
    expect(
      () => GpuMesh('negative', cgl, glTriangles, {aPosition: -1}),
      throwsArgumentError,
    );
    expect(cgl.vaos, hasLength(count));
  });

  test('Program and later meshes retain the compiled attribute layout', () {
    final prog = program([aPosition]);
    expect(
      () => prog.shaderObjectV.getAttributeLayoutMap()[aPosition] = 5,
      throwsUnsupportedError,
    );
    final gpu = mesh(prog);
    expect(prog.attributeLayout.attributes[aPosition]!.location, 0);
    expect(gpu.attributeLayout.attributes[aPosition]!.location, 0);
    final target = Framebuffer.screen(cgl)..activate(0, 0, 0, 2, 2);
    addTearDown(target.dispose);
    prog.draw(gpu, []);
    expect(target.extractByteData(null, 0, 0, 2, 2), [
      for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
    ]);
    expect(cgl.getError(), glNoError);
  });

  test('Compatible distinct programs and subset programs share a GPU mesh', () {
    final superset = program([aPosition, aColor]);
    final equal = program([aPosition, aColor]);
    final subset = program([aPosition]);
    final gpu = mesh(superset)..addAttribute(aColor, Float32List(9), 3);
    expect(superset.hasCompatibleAttributesTo(equal), isTrue);
    expect(subset.hasDownwardCompatibleAttributesTo(superset), isTrue);
    expect(superset.hasDownwardCompatibleAttributesTo(subset), isFalse);
    expect(gpu.isCompatibleWith(equal), isTrue);
    expect(gpu.isCompatibleWith(subset), isTrue);
    final target = Framebuffer.screen(cgl)..activate(0, 0, 0, 2, 2);
    addTearDown(target.dispose);
    final stats = <DrawStats>[];
    equal.draw(gpu, [], stats);
    subset.draw(gpu, [], stats);
    expect(stats, hasLength(2));
    expect(target.extractByteData(null, 0, 0, 2, 2), [
      for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
    ]);
    expect(cgl.getError(), glNoError);
  });

  test('Reordered locations fail before reading uniforms or activating GL', () {
    final original = program([aPosition, aColor]);
    final reordered = program([aColor, aPosition]);
    final gpu = mesh(original)..addAttribute(aColor, Float32List(9), 3);
    final uniforms = _CountingUniforms();
    final stats = <DrawStats>[];
    expect(original.hasCompatibleAttributesTo(reordered), isFalse);
    expect(gpu.isCompatibleWith(reordered), isFalse);
    cgl.activations = 0;
    expect(() => reordered.draw(gpu, [uniforms], stats), throwsArgumentError);
    expect(uniforms.reads, 0);
    expect(cgl.activations, 0);
    expect(stats, isEmpty);
    original.draw(gpu, []);
    expect(cgl.activations, 1);
    expect(cgl.getError(), glNoError);
  });

  test('Missing layout attributes and a different context reject sharing', () {
    final original = program([aPosition]);
    final more = program([aPosition, aNormal]);
    final otherContext = program([aPosition], gl: context());
    final gpu = mesh(original);
    expect(gpu.isCompatibleWith(more), isFalse);
    expect(gpu.isCompatibleWith(otherContext), isFalse);
    expect(original.hasCompatibleAttributesTo(otherContext), isFalse);
    expect(() => more.draw(gpu, []), throwsArgumentError);
    expect(() => otherContext.draw(gpu, []), throwsArgumentError);
  });

  test(
    'CPU and GPU imports share custom attribute types and integer uploads',
    () {
      const ids = 'aLayoutIds';
      cpu.introduceNewShaderVar(
        ids,
        const cpu.ShaderVarDesc(cpu.varTypeUvec4, 'layout integer readback'),
      );
      expect(retrieveShaderVarDesc(ids).type, varTypeUvec4);
      final vertex = ShaderObject('integer-v')
        ..addAttributeVars([aPosition, ids])
        ..addVaryingVars([vColor])
        ..setBodyWithMain([
          'gl_Position = vec4($aPosition, 1.0);',
          '$vColor = vec3($ids.xyz) / 255.0;',
        ]);
      final fragment = ShaderObject('integer-f')
        ..addVaryingVars([vColor])
        ..setBodyWithMain(['$oFragColor = vec4($vColor, 1.0);']);
      final prog = RenderProgram('integer layout', cgl, vertex, fragment);
      addTearDown(prog.dispose);
      final gb = cpu.GeometryBuilder()
        ..addVertices([
          vm.Vector3(-1, -1, 0),
          vm.Vector3(3, -1, 0),
          vm.Vector3(-1, 3, 0),
        ])
        ..addFace3(0, 1, 2);
      gb.attributes[ids] = <Object>[
        [255, 128, 0, 42],
        [255, 128, 0, 42],
        [255, 128, 0, 42],
      ];
      final gpu = uploadGeometry('integer', prog, gb);
      addTearDown(gpu.dispose);
      expect(gpu.attributeLayout.attributes[ids]!.isInteger, isTrue);
      (gb.attributes[ids]!.first as List<int>)[0] = 0;
      final target = Framebuffer.screen(cgl)..activate(0, 0, 0, 2, 2);
      addTearDown(target.dispose);
      prog.draw(gpu, []);
      expect(target.extractByteData(null, 0, 0, 2, 2), [
        for (var i = 0; i < 4; i++) ...[255, 128, 0, 255],
      ]);
      // Direct callers may provide ordinary lists rather than typed data.
      final values = <num>[
        for (var i = 0; i < 3; i++) ...[0, 255, 128, 42],
      ];
      gpu.addAttribute(ids, values, 4);
      final before = cgl.buffers.length;
      expect(
        () => gpu.addAttribute(ids, List<double>.filled(12, 0.5), 4),
        throwsArgumentError,
      );
      expect(cgl.buffers, hasLength(before));
      target.activate(glDepthBufferBit, 0, 0, 2, 2);
      prog.draw(gpu, []);
      expect(target.extractByteData(null, 0, 0, 2, 2), [
        for (var i = 0; i < 4; i++) ...[0, 255, 128, 255],
      ]);
      expect(cgl.getError(), glNoError);
    },
  );

  test(
    'Instance layouts configure divisors for shared compatible programs',
    () {
      final vertex = ShaderObject('instance-v')
        ..addAttributeVars([aPosition, iaTranslation])
        ..setBodyWithMain([
          'gl_Position = vec4($aPosition + $iaTranslation, 1.0);',
        ]);
      final fragment = ShaderObject('instance-f')
        ..setBodyWithMain(['$oFragColor = vec4(0.0, 1.0, 0.0, 1.0);']);
      final first = RenderProgram('instance first', cgl, vertex, fragment);
      final second = RenderProgram('instance second', cgl, vertex, fragment);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final gpu = mesh(first)..addAttribute(iaTranslation, Float32List(6), 3);
      expect(gpu.attributeLayout.attributes[iaTranslation]!.divisor, 1);
      final target = Framebuffer.screen(cgl)..activate(0, 0, 0, 2, 2);
      addTearDown(target.dispose);
      final stats = <DrawStats>[];
      second.draw(gpu, [], stats);
      expect(stats.single.numInstances, 2);
      expect(target.extractByteData(null, 0, 0, 2, 2), [
        for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
      ]);
      expect(cgl.getError(), glNoError);
    },
  );

  test('Empty triangle geometry uploads with an index buffer', () {
    final gpu = uploadGeometry(
      'empty',
      program([aPosition]),
      GeometryBuilder(),
    );
    addTearDown(gpu.dispose);
    expect(gpu.drawMode, glTriangles);
    expect(gpu.elementArrayBufferType, glUnsignedByte);
    expect(gpu.getNumItems(), 0);
    expect(cgl.getError(), glNoError);
  });

  test(
    'Normal lines allocate only after validation and release failed uploads',
    () {
      final prog = program([aPosition]);
      final missing = cubeGeometry(computeNormals: false);
      expect(
        () => geometryBuilderToWireframeNormals(prog, missing),
        throwsStateError,
      );
      expect(cgl.vaos, isEmpty);
      expect(cgl.buffers, isEmpty);

      final geometry = cubeGeometry();
      cgl.failBufferNumber = 2;
      expect(
        () => geometryBuilderToWireframeNormals(prog, geometry),
        throwsA(same(cgl.failure)),
      );
      expect(cgl.buffers, hasLength(1));
      expect(cgl.vaos, hasLength(1));
      expect(cgl.deletedBuffers, cgl.buffers);
      expect(cgl.deletedVaos, cgl.vaos);
    },
  );

  for (final wireframe in [false, true]) {
    test(
      'Upload ${wireframe ? 'wireframe' : 'triangles'} snapshots CPU geometry',
      () {
        final prog = program([aPosition, aTexUV]);
        final gb = quadGeometry(1);
        gb.attributes[aTexUV] = List<Object>.of(gb.attributes[aTexUV]!);
        final gpu = wireframe
            ? uploadWireframeGeometry('quad', prog, gb)
            : uploadGeometry('quad', prog, gb);
        addTearDown(gpu.dispose);
        final positions = List<num>.from(gpu.getAttribute(aPosition));
        final uvs = List<num>.from(gpu.getAttribute(aTexUV));
        gb.vertices.first.setZero();
        (gb.attributes[aTexUV]!.first as vm.Vector2).setZero();
        gb.vertices.clear();
        expect(gpu.getAttribute(aPosition), positions);
        expect(gpu.getAttribute(aTexUV), uvs);
        expect(gpu.drawMode, wireframe ? glLines : glTriangles);
        expect(gpu.getNumItems(), wireframe ? 8 : 6);
        expect(cgl.getError(), glNoError);
      },
    );

    test(
      'Invalid ${wireframe ? 'wireframe' : 'triangle'} CPU geometry allocates nothing',
      () {
        final prog = program([aPosition]);
        final gb = quadGeometry(1)..vertices.removeLast();
        expect(
          () => wireframe
              ? uploadWireframeGeometry('bad', prog, gb)
              : uploadGeometry('bad', prog, gb),
          throwsStateError,
        );
        expect(cgl.vaos, isEmpty);
        expect(cgl.buffers, isEmpty);
      },
    );

    test(
      'Failed ${wireframe ? 'wireframe' : 'triangle'} upload releases partial storage',
      () {
        final prog = program([aPosition]);
        final gb = quadGeometry(1);
        cgl.failBufferNumber = 2;
        expect(
          () => wireframe
              ? uploadWireframeGeometry('failure', prog, gb)
              : uploadGeometry('failure', prog, gb),
          throwsA(same(cgl.failure)),
        );
        expect(cgl.deletedBuffers, unorderedEquals(cgl.buffers));
        expect(cgl.deletedVaos, unorderedEquals(cgl.vaos));
        expect(gb.vertices, hasLength(4));
        cgl.failBufferNumber = null;
        final next = uploadGeometry('recovered', prog, gb);
        addTearDown(next.dispose);
        expect(next.getNumItems(), 6);
        expect(cgl.getError(), glNoError);
      },
    );
  }
}
