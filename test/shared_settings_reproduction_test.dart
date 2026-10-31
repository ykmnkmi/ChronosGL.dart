@TestOn('chrome')
library;

import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

// Characterize current bugs; these are not the desired ownership contracts.
// Replace shared-mutation expectations in phase 6 (6.4, 6.9, 6.11).
// See docs/1.9_SHARED_SETTINGS_AND_FRAME_RATE_REPRODUCTIONS.md.
ChronosGL _context(web.HTMLCanvasElement canvas) {
  final cgl = ChronosGL(canvas, antialiasing: false);
  addTearDown(() {
    (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
        ?.loseContext();
  });
  return cgl;
}

void main() {
  test('Known bug: editing one material color changes the shared palette', () {
    final original = vm.Vector3.copy(colorWhite);
    addTearDown(() => colorWhite.setFrom(original));
    expect(original.storage, [1, 1, 1]);
    final first = Material('first')..setUniform(uColor, colorWhite);
    final second = Material('second')..setUniform(uColor, colorWhite);
    final independent = Material('independent')
      ..setUniform(uColor, vm.Vector3.copy(colorWhite));

    (first.getUniforms()[uColor]! as vm.Vector3).setValues(0, 1, 0);

    expect((second.getUniforms()[uColor]! as vm.Vector3).storage, [0, 1, 0]);
    expect(colorWhite.storage, [0, 1, 0]);
    final later = Material('later')..setUniform(uColor, colorWhite);
    expect((later.getUniforms()[uColor]! as vm.Vector3).storage, [0, 1, 0]);
    expect((independent.getUniforms()[uColor]! as vm.Vector3).storage, [
      1,
      1,
      1,
    ]);
  });

  for (final transparent in [false, true]) {
    test(
      'Known bug: materials share blend settings (transparent=$transparent)',
      () {
        final preset = transparent ? blendEquationStandard : blendEquationNone;
        final original = (preset.equation, preset.srcFactor, preset.dstFactor);
        addTearDown(() {
          preset.equation = original.$1;
          preset.srcFactor = original.$2;
          preset.dstFactor = original.$3;
        });
        Material material(String name) => transparent
            ? Material.transparent(name, blendEquationStandard)
            : Material(name);
        final first = material('first');
        final second = material('second');
        final independent = Material.transparent(
          'independent',
          TheBlendEquation(original.$1, original.$2, original.$3),
        );
        final edited = first.getUniforms()[cBlendEquation]! as TheBlendEquation;
        edited
          ..equation = glFuncAdd
          ..srcFactor = glOne
          ..dstFactor = glOne;

        for (final consumer in [second, material('later')]) {
          final blend =
              consumer.getUniforms()[cBlendEquation]! as TheBlendEquation;
          expect(blend, same(preset));
          expect(
            (blend.equation, blend.srcFactor, blend.dstFactor),
            (glFuncAdd, glOne, glOne),
          );
        }
        final copy =
            independent.getUniforms()[cBlendEquation]! as TheBlendEquation;
        expect((copy.equation, copy.srcFactor, copy.dstFactor), original);
        expect(original, isNot((glFuncAdd, glOne, glOne)));
      },
    );
  }

  test('Known bug: materials share the stencil function preset', () {
    final original = stencilFunctionAlways.func;
    addTearDown(() => stencilFunctionAlways.func = original);
    expect(original, glAlways);
    final first = Material('first')
      ..setUniform(cStencilFunc, stencilFunctionAlways);
    final second = Material('second')
      ..setUniform(cStencilFunc, stencilFunctionAlways);

    (first.getUniforms()[cStencilFunc]! as TheStencilFunction).func = glNever;

    expect(
      (second.getUniforms()[cStencilFunc]! as TheStencilFunction).func,
      glNever,
    );
    expect(stencilFunctionAlways.func, glNever);
    final later = Material('later')
      ..setUniform(cStencilFunc, stencilFunctionAlways);
    expect(
      (later.getUniforms()[cStencilFunc]! as TheStencilFunction).func,
      glNever,
    );
  });

  test(
    'Known bug: texture preset mutation affects other textures on install',
    () {
      final preset = texturePropertiesFramebuffer;
      final original = (preset.minFilter, preset.magFilter);
      addTearDown(() {
        preset.minFilter = original.$1;
        preset.magFilter = original.$2;
      });
      expect(original, (glNearest, glNearest));
      final canvas = web.HTMLCanvasElement()
        ..width = 2
        ..height = 2;
      final cgl = _context(canvas);
      final gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
      TypedTexture texture(String name, TextureProperties properties) =>
          TypedTexture(cgl, name, 1, 1, glRgba8, properties);
      final first = texture('first', preset);
      final second = texture('second', preset);
      final independent = texture(
        'independent',
        TextureProperties()..setFilterNearest(),
      );
      void expectFilters(Texture texture, int filter) {
        cgl.bindTexture(glTexture2D, texture.getTexture());
        expect(
          gl.getTexParameter(glTexture2D, glTextureMinFilter).dartify(),
          filter,
        );
        expect(
          gl.getTexParameter(glTexture2D, glTextureMagFilter).dartify(),
          filter,
        );
      }

      expectFilters(first, glNearest);
      expectFilters(second, glNearest);
      first.properties
        ..minFilter = glLinear
        ..magFilter = glLinear;

      expect(second.properties, same(preset));
      expect(
        (second.properties.minFilter, second.properties.magFilter),
        (glLinear, glLinear),
      );
      // CPU settings change immediately; existing GPU state changes on install.
      expectFilters(second, glNearest);
      second.install();
      expectFilters(second, glLinear);
      expectFilters(texture('later', preset), glLinear);
      independent.install();
      expectFilters(independent, glNearest);
      expect(cgl.getError(), glNoError);
    },
  );

  test('Known bug: unitNode shares a mutable material with other nodes', () {
    final original = Map<String, Object>.of(emptyMaterial.getUniforms());
    addTearDown(() {
      emptyMaterial.getUniforms()
        ..clear()
        ..addAll(original);
    });
    expect(original[cDepthWrite], isTrue);
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    final cgl = _context(canvas);
    final vertex = ShaderObject('unit-v')
      ..addAttributeVars([aPosition])
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('unit-f')
      ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
    final program = RenderProgram('unit', cgl, vertex, fragment);
    final first = unitNode(program);
    final second = unitNode(program);
    expect(first.meshData, isNot(same(second.meshData)));

    first.material.forceUniform(cDepthWrite, false);

    expect(second.material, same(emptyMaterial));
    expect(second.material.getUniforms()[cDepthWrite], isFalse);
    expect(unitNode(program).material.getUniforms()[cDepthWrite], isFalse);
    expect(Material('independent').getUniforms()[cDepthWrite], isTrue);
    expect(cgl.getError(), glNoError);
  });
}
