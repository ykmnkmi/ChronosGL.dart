part of 'lib.dart';

class TheStencilFunction {
  TheStencilFunction(this.func, this.value, this.mask);

  int func;
  int value;
  int mask;
}

final TheStencilFunction stencilFunctionNone = TheStencilFunction(
  glInvalidValue,
  0,
  ~0,
);

final TheStencilFunction stencilFunctionAlways = TheStencilFunction(
  glAlways,
  0,
  ~0,
);

class TheStencilOp {
  TheStencilOp(this.fail, this.zfail, this.zpass);

  int fail;
  int zfail;
  int zpass;
}

class TheBlendEquation {
  TheBlendEquation(this.equation, this.srcFactor, this.dstFactor);

  int equation;
  int srcFactor;
  int dstFactor;
}

final TheBlendEquation blendEquationNone = TheBlendEquation(
  glInvalidValue,
  glInvalidValue,
  glInvalidValue,
);

// dst was GL_ONE
final TheBlendEquation blendEquationStandard = TheBlendEquation(
  glFuncAdd,
  glSrcAlpha,
  glOneMinusSrcAlpha,
);

final TheBlendEquation blendEquationMix = TheBlendEquation(
  glFuncAdd,
  glSrcAlpha,
  glOneMinusSrcColor,
);

final TheBlendEquation blendEquationAdd = TheBlendEquation(
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
