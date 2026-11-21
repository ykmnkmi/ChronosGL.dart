@TestOn('chrome')
library;

import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

// Check that editing one consumer's settings leaves other consumers unchanged.
ChronosGL _context(web.HTMLCanvasElement canvas) {
  final cgl = ChronosGL(canvas, antialiasing: false);
  addTearDown(() {
    (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
        ?.loseContext();
  });
  return cgl;
}

void main() {
  test('Palette adapters isolate material colors and later consumers', () {
    final first = Material('first')..setUniform(uColor, colorWhite.toVector3());
    final second = Material('second')
      ..setUniform(uColor, colorWhite.toVector3());

    (first.getUniforms()[uColor]! as vm.Vector3).setValues(0, 1, 0);

    expect((second.getUniforms()[uColor]! as vm.Vector3).storage, [1, 1, 1]);
    expect(colorWhite, const Color(1, 1, 1));
    final later = Material('later')..setUniform(uColor, colorWhite.toVector3());
    expect((later.getUniforms()[uColor]! as vm.Vector3).storage, [1, 1, 1]);
    expect(colorWhite.copyWith(r: 0, b: 0), colorGreen);
    expect(colorWhite.toVector3().storage, [1, 1, 1]);
  });

  for (final transparent in [false, true]) {
    test('Blend variants isolate materials (transparent=$transparent)', () {
      final preset = transparent ? blendEquationStandard : blendEquationNone;
      final original = (preset.equation, preset.srcFactor, preset.dstFactor);
      Material material(String name) => transparent
          ? Material.transparent(name, blendEquationStandard)
          : Material(name);
      final first = material('first');
      final second = material('second');

      first.forceUniform(
        cBlendEquation,
        preset.copyWith(
          equation: glFuncAdd,
          srcFactor: glOne,
          dstFactor: glOne,
        ),
      );

      for (final consumer in [second, material('later')]) {
        final blend =
            consumer.getUniforms()[cBlendEquation]! as TheBlendEquation;
        expect(blend, same(preset));
        expect((blend.equation, blend.srcFactor, blend.dstFactor), original);
      }
      final edited = first.getUniforms()[cBlendEquation]! as TheBlendEquation;
      expect(
        (edited.equation, edited.srcFactor, edited.dstFactor),
        (glFuncAdd, glOne, glOne),
      );
      expect(
        () => (preset as dynamic).srcFactor = glOne,
        throwsNoSuchMethodError,
      );
    });
  }

  test('Stencil variants preserve shared functions and operations', () {
    final first = Material('first')
      ..setUniform(cStencilFunc, stencilFunctionAlways);
    final second = Material('second')
      ..setUniform(cStencilFunc, stencilFunctionAlways);
    const originalOp = TheStencilOp(glKeep, glKeep, glKeep);
    first.setUniform(cStencilOp, originalOp);
    second.setUniform(cStencilOp, originalOp);

    first
      ..forceUniform(
        cStencilFunc,
        stencilFunctionAlways.copyWith(func: glNever),
      )
      ..forceUniform(cStencilOp, originalOp.copyWith(zpass: glReplace));

    expect(
      (first.getUniforms()[cStencilFunc]! as TheStencilFunction).func,
      glNever,
    );
    expect(
      (second.getUniforms()[cStencilFunc]! as TheStencilFunction).func,
      glAlways,
    );
    expect(stencilFunctionAlways.func, glAlways);
    expect((first.getUniforms()[cStencilOp]! as TheStencilOp).zpass, glReplace);
    expect(second.getUniforms()[cStencilOp], same(originalOp));
    expect(originalOp.zpass, glKeep);
    expect(
      () => (stencilFunctionAlways as dynamic).func = glNever,
      throwsNoSuchMethodError,
    );
    expect(
      () => (originalOp as dynamic).zpass = glReplace,
      throwsNoSuchMethodError,
    );
  });

  test('Texture variants preserve other consumers on install', () {
    const preset = texturePropertiesFramebuffer;
    final variant = preset.copyWith(minFilter: glLinear, magFilter: glLinear);
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    final cgl = _context(canvas);
    final gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    TypedTexture texture(String name, TextureProperties properties) {
      final result = TypedTexture(cgl, name, 1, 1, glRgba8, properties);
      addTearDown(result.dispose);
      return result;
    }

    final first = texture('first', variant);
    final second = texture('second', preset);
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

    expectFilters(first, glLinear);
    expect(second.properties, same(preset));
    second.install();
    expectFilters(second, glNearest);
    expectFilters(texture('later', preset), glNearest);
    expect((preset.minFilter, preset.magFilter), (glNearest, glNearest));
    expect(
      (variant.clamp, variant.flipY, variant.shadow),
      (true, false, false),
    );
    expect(
      () => (first.properties as dynamic).minFilter = glNearest,
      throwsNoSuchMethodError,
    );
    expect(cgl.getError(), glNoError);
  });

  test('Texture sampling variants retain unrelated settings', () {
    const original = TextureProperties(
      clamp: true,
      shadow: true,
      flipY: false,
      anisotropicFilterLevel: 4,
    );
    final mipmapped = original.withMipmapLinear();
    final nearest = mipmapped.withFilterNearest();
    expect(mipmapped.mipmap, isTrue);
    expect(mipmapped.minFilter, glLinearMipmapLinear);
    expect(mipmapped.magFilter, glLinear);
    expect((nearest.minFilter, nearest.magFilter), (glNearest, glNearest));
    expect(nearest.mipmap, isTrue);
    expect(nearest.clamp, isTrue);
    expect(nearest.shadow, isTrue);
    expect(nearest.flipY, isFalse);
    expect(nearest.anisotropicFilterLevel, 4);
    expect(original.mipmap, isFalse);
    expect(original.minFilter, glLinear);
    expect(nearest.copyWith(mipmap: false, clamp: false).clamp, isFalse);
    expect(texturePropertiesShadowMap.shadow, isTrue);
    expect(texturePropertiesFramebufferWrapped.clamp, isFalse);
  });

  test('unitNode creates independent materials for every consumer', () {
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
    addTearDown(program.dispose);
    MeshNode node() {
      final result = unitNode(program);
      addTearDown(result.meshData.dispose);
      return result;
    }

    final first = node();
    final second = node();
    expect(first.meshData, isNot(same(second.meshData)));
    expect(first.material, isNot(same(second.material)));

    first.material.forceUniform(cDepthWrite, false);

    expect(second.material.getUniforms()[cDepthWrite], isTrue);
    expect(node().material.getUniforms()[cDepthWrite], isTrue);
    expect(cgl.getError(), glNoError);
  });
}
