part of 'lib.dart';

/// Immutable stencil comparison settings. Use [copyWith] to create a variant.
class TheStencilFunction {
  const TheStencilFunction(this.func, this.value, this.mask);

  const TheStencilFunction.create({
    required this.func,
    required this.value,
    required this.mask,
  });

  final int func;
  final int value;
  final int mask;

  TheStencilFunction copyWith({int? func, int? value, int? mask}) =>
      TheStencilFunction(
        func ?? this.func,
        value ?? this.value,
        mask ?? this.mask,
      );
}

const TheStencilFunction stencilFunctionNone = TheStencilFunction(
  glInvalidValue,
  0,
  ~0,
);

const TheStencilFunction stencilFunctionAlways = TheStencilFunction(
  glAlways,
  0,
  ~0,
);

/// Immutable stencil operations for stencil failure, depth failure and success.
class TheStencilOp {
  const TheStencilOp(this.fail, this.zfail, this.zpass);

  const TheStencilOp.create({
    required this.fail,
    required this.zfail,
    required this.zpass,
  });

  final int fail;
  final int zfail;
  final int zpass;

  TheStencilOp copyWith({int? fail, int? zfail, int? zpass}) =>
      TheStencilOp(fail ?? this.fail, zfail ?? this.zfail, zpass ?? this.zpass);
}

/// Immutable blending settings. Materials can safely share a preset.
class TheBlendEquation {
  const TheBlendEquation(this.equation, this.srcFactor, this.dstFactor);

  const TheBlendEquation.create({
    required this.equation,
    required this.srcFactor,
    required this.dstFactor,
  });

  final int equation;
  final int srcFactor;
  final int dstFactor;

  TheBlendEquation copyWith({int? equation, int? srcFactor, int? dstFactor}) =>
      TheBlendEquation(
        equation ?? this.equation,
        srcFactor ?? this.srcFactor,
        dstFactor ?? this.dstFactor,
      );
}

const TheBlendEquation blendEquationNone = TheBlendEquation(
  glInvalidValue,
  glInvalidValue,
  glInvalidValue,
);

const TheBlendEquation blendEquationStandard = TheBlendEquation(
  glFuncAdd,
  glSrcAlpha,
  glOneMinusSrcAlpha,
);

const TheBlendEquation blendEquationMix = TheBlendEquation(
  glFuncAdd,
  glSrcAlpha,
  glOneMinusSrcColor,
);

const TheBlendEquation blendEquationAdd = TheBlendEquation(
  glFuncAdd,
  glOne,
  glOne,
);

/// is a light weight container for uniforms related to the appearance
/// of a mesh.
/// At most one Material can be passed to the RenderProgram::draw() call
/// because it controls the depth, stencil, and blending behavior
class Material extends UniformGroup {
  Material(super.name) {
    setUniform(cDepthFunc, glLess);
    setUniform(cDepthTest, true);
    setUniform(cDepthWrite, true);
    setUniform(cBlendEquation, blendEquationNone);
  }

  Material.transparent(super.name, TheBlendEquation beq) {
    setUniform(cDepthFunc, glLess);
    setUniform(cDepthTest, true);
    setUniform(cDepthWrite, false);
    setUniform(cBlendEquation, beq);
  }

  Material.empty(super.name);
}
