import 'package:chronosgl/shaders.dart';
import 'package:test/test.dart';

void main() {
  test('Explicit vertex stage supports gl_VertexID without attributes', () {
    final vertex =
        ShaderObject.create(
            name: 'generated triangle',
            stage: ShaderStage.vertex,
          )
          ..addVaryingVars([vColor])
          ..setBodyWithMain([
            '$vColor = vec3(1.0);',
            'gl_Position = vec4(float(gl_VertexID), 0.0, 0.0, 1.0);',
          ]);
    expect(vertex.stage, ShaderStage.vertex);
    expect(vertex.attributeVars, isEmpty);
    expect(vertex.shader, contains('out vec3 $vColor;'));
    expect(vertex.shader, isNot(contains('out vec4 $oFragColor;')));
  });

  test('Explicit fragment stage uses inputs and rejects vertex interfaces', () {
    final fragment = ShaderObject.fragment('fragment')
      ..addVaryingVars([vColor])
      ..setBodyWithMain(['$oFragColor = vec4($vColor, 1.0);']);
    expect(fragment.shader, contains('in vec3 $vColor;'));
    expect(fragment.shader, contains('out vec4 $oFragColor;'));
    expect(
      () => ShaderObject.fragment('bad').addAttributeVars([aPosition]),
      throwsUnsupportedError,
    );
    expect(
      () => ShaderObject.fragment('bad').addTransformVars([tPosition]),
      throwsUnsupportedError,
    );
  });

  test('Interface updates fail atomically and source freezes metadata', () {
    final shader = ShaderObject.vertex('metadata')
      ..addAttributeVars([aPosition]);
    expect(
      () => shader.addAttributeVars([aNormal, aPosition]),
      throwsArgumentError,
    );
    expect(shader.attributeVars, [aPosition]);
    expect(shader.getAttributeLayoutMap(), {aPosition: 0});
    expect(() => shader.attributeVars.add(aNormal), throwsUnsupportedError);
    expect(
      () => shader.getAttributeLayoutMap()[aNormal] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => shader.addUniformVars(['uUnregisteredPhase7']),
      throwsArgumentError,
    );
    shader.setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    expect(() => shader.addUniformVars([uTime]), throwsStateError);
    expect(() => shader.setBodyWithMain([]), throwsStateError);
    expect(() => shader.shader = 'replacement', throwsStateError);
  });

  test('Custom variable registration rejects duplicates without replacing metadata', () {
    expect(
      () =>
          introduceNewShaderVar(uTime, const ShaderVarDesc(varTypeVec3, 'bad')),
      throwsArgumentError,
    );
    expect(retrieveShaderVarDesc(uTime).type, varTypeFloat);
    expect(
      () => introduceNewShaderVar('', const ShaderVarDesc(varTypeFloat, 'bad')),
      throwsArgumentError,
    );
    expect(
      () => const ShaderVarDesc(varTypeSampler2D, '').getSize(),
      throwsUnsupportedError,
    );
  });

  test('Uniform keys retain runtime value type after generic widening', () {
    const UniformKey<Object> key = UniformKey<num>(uTime);
    key.validateValue(2.5);
    expect(() => key.validateValue('invalid'), throwsArgumentError);
    expect(
      () => const UniformKey<num>('notAUniform').validateValue(1),
      throwsArgumentError,
    );
  });

  test(
    'Dynamic shader factories declare stages and reject invalid options',
    () {
      expect(
        createBloomTextureFragmentShader(3, 1).stage,
        ShaderStage.fragment,
      );
      expect(
        makePerlinNoiseColorFragmentShader(false).stage,
        ShaderStage.fragment,
      );
      expect(
        makePerlinNoiseColorFragmentShader(true).stage,
        ShaderStage.fragment,
      );
      expect(crosshatchFragmentShader(0).stage, ShaderStage.fragment);
      expect(crosshatchFragmentShader(1).stage, ShaderStage.fragment);
      expect(createPlane2GreyShader().map((s) => s.stage), [
        ShaderStage.vertex,
        ShaderStage.fragment,
      ]);
      expect(createPlane2ColorShader().map((s) => s.stage), [
        ShaderStage.vertex,
        ShaderStage.fragment,
      ]);
      expect(() => createBloomTextureFragmentShader(0, 1), throwsArgumentError);
      for (final sigma in [0.0, -1.0, double.nan, double.infinity, 1e-320]) {
        expect(
          () => createBloomTextureFragmentShader(3, sigma),
          throwsArgumentError,
        );
      }
      expect(() => crosshatchFragmentShader(2), throwsArgumentError);
    },
  );

  test('Built-in descriptions use declared stages on the VM', () {
    expect(solidColorVertexShader.stage, ShaderStage.vertex);
    expect(solidColorFragmentShader.stage, ShaderStage.fragment);
    expect(texturedVertexShader.stage, ShaderStage.vertex);
    expect(copyFragmentShader.stage, ShaderStage.fragment);
  });
}
