@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/render.dart';
import 'package:chronosgl/shaders.dart';
import 'package:chronosgl/webgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

class _RawUniformGroup extends UniformGroup {
  _RawUniformGroup(this.values) : super('raw override');

  final Map<String, Object> values;

  @override
  Map<String, Object> getUniforms() => values;
}

void main() {
  test('Typed and string uniforms share storage with checked updates', () {
    final group = UniformGroup('typed')..set(UniformKeys.time, 2.5);
    expect(group.getUniforms()[uTime], 2.5);
    expect(group.get(UniformKeys.time), 2.5);
    group.forceUniform(uTime, 3);
    expect(group.get(UniformKeys.time), 3);
    group.force(UniformKeys.time, 4);
    expect(group.getUniforms()[uTime], 4);
    expect(() => group.set(UniformKeys.time, 5), throwsStateError);
    expect(group.get(UniformKeys.time), 4);
    const UniformKey<Object> widened = UniformKey<num>(uTime);
    expect(() => group.force(widened, 'bad'), throwsArgumentError);
    expect(
      () => group.force(const UniformKey<num>(uColor), 1),
      throwsArgumentError,
    );
    expect(
      () => group.force(UniformKeys.boneMatrices, Float32List(3)),
      throwsArgumentError,
    );
    expect(group.get(UniformKeys.time), 4);
    // A shader array may receive an aligned prefix up to its declared capacity.
    group.set(UniformKeys.boneMatrices, Float32List(16));
    expect(group.get(UniformKeys.boneMatrices), hasLength(16));
    final red = vm.Vector3(1, 0, 0);
    group.set(UniformKeys.color, red);
    expect(group.get(UniformKeys.color), same(red));
  });

  test('Uniform maps are immutable snapshots with controlled removal', () {
    final group = UniformGroup('snapshot')..set(UniformKeys.time, 1);
    final snapshot = group.getUniforms();
    expect(() => snapshot[uTime] = 2, throwsUnsupportedError);
    group.force(UniformKeys.time, 3);
    expect(snapshot[uTime], 1);
    group.addUniforms({uOpacity: 0.5});
    expect(group.removeUniform(uOpacity), 0.5);
    group.clearUniforms();
    expect(group.getUniforms(), isEmpty);
    expect(() => group.forceUniform('', 1), throwsArgumentError);
  });

  test(
    'Invalid rendering controls fail before changing the current program',
    () {
      final canvas = web.HTMLCanvasElement()
        ..width = 2
        ..height = 2;
      final cgl = ChronosGL(canvas);
      addTearDown(() {
        (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
            ?.loseContext();
      });
      final vertex = ShaderObject.vertex('controls vertex')
        ..setBodyWithMain(['gl_Position = vec4(0.0);']);
      final fragment = ShaderObject.fragment('controls fragment')
        ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
      final program = RenderProgram.create(
        name: 'controls',
        context: cgl,
        vertexShader: vertex,
        fragmentShader: fragment,
      );
      addTearDown(program.dispose);
      final mesh = program.makeGpuMesh('empty', glTriangles);
      addTearDown(mesh.dispose);
      final sentinel = cgl.compileWholeProgram(
        vertex.shader!,
        fragment.shader!,
        [],
      );
      addTearDown(() => cgl.deleteProgram(sentinel));
      cgl.useProgram(sentinel);

      final invalid = <String, Object>{
        cDepthTest: 'false',
        cDepthWrite: 1,
        cDepthFunc: false,
        cStencilWrite: 'mask',
        cStencilFunc: 1,
        cStencilOp: 1,
        cBlendEquation: 1,
        cColorWrite: [true, false],
      };
      for (final entry in invalid.entries) {
        final group = UniformGroup('invalid ${entry.key}')
          ..setUniform(entry.key, entry.value);
        expect(
          () => program.draw(mesh, [group]),
          throwsArgumentError,
          reason: entry.key,
        );
        expect(cgl.getParameter(glCurrentProgram), sentinel);
        expect(cgl.getError(), glNoError);
      }
      final unknown = UniformGroup('unknown')
        ..setUniform('cUnknownPhase7', true);
      expect(() => program.draw(mesh, [unknown]), throwsUnsupportedError);
      expect(cgl.getParameter(glCurrentProgram), sentinel);
      expect(
        () => program.draw(mesh, [
          _RawUniformGroup({'': true}),
        ]),
        throwsArgumentError,
      );
      expect(cgl.getParameter(glCurrentProgram), sentinel);
      expect(cgl.getError(), glNoError);
    },
  );

  test(
    'Explicit attribute-free vertex shader compiles and stage mismatch fails',
    () {
      final canvas = web.HTMLCanvasElement()
        ..width = 2
        ..height = 2;
      final cgl = ChronosGL(canvas);
      addTearDown(() {
        (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
            ?.loseContext();
      });
      final vertex = ShaderObject.vertex('generated')
        ..setBodyWithMain([
          'gl_Position = vec4(float(gl_VertexID), 0.0, 0.0, 1.0);',
        ]);
      final fragment = ShaderObject.fragment('white')
        ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
      final program = RenderProgram.create(
        name: 'generated',
        context: cgl,
        vertexShader: vertex,
        fragmentShader: fragment,
      );
      addTearDown(program.dispose);
      expect(program.attributeLayout.attributes, isEmpty);
      expect(
        () => RenderProgram.create(
          name: 'wrong stages',
          context: cgl,
          vertexShader: fragment,
          fragmentShader: vertex,
        ),
        throwsArgumentError,
      );
      expect(
        () => RenderProgram.create(
          name: 'unfinished',
          context: cgl,
          vertexShader: ShaderObject.vertex('unfinished'),
          fragmentShader: fragment,
        ),
        throwsStateError,
      );
    },
  );
}
