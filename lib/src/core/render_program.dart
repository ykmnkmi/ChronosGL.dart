part of 'lib.dart';

/// Helper class for holding info produced by RenderProgram::draw().
class DrawStats {
  DrawStats(
    this.name,
    this.numInstances,
    this.numItems,
    this.drawMode,
    this.duration,
  );

  final String name;
  final int numInstances;
  final int numItems;
  final int drawMode;
  final Duration duration;

  @override
  String toString() =>
      "[$name] $numInstances $numItems mode:$drawMode [${duration.inMicroseconds}usec]";
}

/// represents program (Fragment + Vertex Shader) running on the GPU with an API to invoke it.
class RenderProgram extends NamedEntity {
  RenderProgram(super.name, this._cgl, this._shaderObjectV, this._shaderObjectF)
    : _program = _cgl.compileWholeProgram(
        _shaderObjectV.shader!,
        _shaderObjectF.shader!,
        _shaderObjectV.transformVars,
      ),
      _attributes = Set.from(_shaderObjectV.attributeVars) {
    for (String v in _shaderObjectV.uniformVars) {
      _uniformLocations[v] = _cgl.getUniformLocation(_program, v)!;
    }

    for (String v in _shaderObjectF.uniformVars) {
      // This can happen! Example both shaders use uTime.
      // assert(!uniformLocations.containsKey(v));
      _uniformLocations[v] = _cgl.getUniformLocation(_program, v)!;
    }
  }

  final ChronosGL _cgl;
  final ShaderObject _shaderObjectV;
  final ShaderObject _shaderObjectF;
  final GlProgram _program;

  final Set<String> _attributes;
  final Map<String, GlUniformLocation> _uniformLocations = {};
  final Map<String, String> _uniformsInitialized = {};
  final Set<String> _attributesInitialized = <String>{};

  int _nextTextureUnit = 0;

  ShaderObject get shaderObjectV => _shaderObjectV;

  ShaderObject get shaderObjectF => _shaderObjectF;

  int getTransformBindingIndex(String canonical) {
    return _shaderObjectV.getTransformBindingIndex(canonical);
  }

  MeshData makeMeshData(String name, int drawMode) {
    return MeshData(
      name,
      _cgl,
      drawMode,
      _shaderObjectV.getAttributeLayoutMap(),
    );
  }

  /// If you want to re-use meshes across programs you can use
  /// this predicate to assert that two programs are compatible.
  bool hasCompatibleAttributesTo(RenderProgram other) {
    var a = _shaderObjectV.getAttributeLayoutMap();
    var b = other._shaderObjectV.getAttributeLayoutMap();
    if (a.length != b.length) return false;
    for (String key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  /// If you want to re-use meshes across programs you can use
  /// this predicate to assert that any mesh for `other` will work
  /// for `this`.
  bool hasDownwardCompatibleAttributesTo(RenderProgram other) {
    var a = _shaderObjectV.getAttributeLayoutMap();
    var b = other._shaderObjectV.getAttributeLayoutMap();
    for (String key in a.keys) {
      if (a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  void _clearState() {
    _nextTextureUnit = 0;
  }

  ChronosGL getContext() => _cgl;

  bool _hasUniform(String canonical) {
    return _uniformLocations.containsKey(canonical);
  }

  void _setControl(String canonical, Object val) {
    switch (canonical) {
      case cDepthTest:
        if (val == true) {
          _cgl.enable(glDepthTest);
        } else {
          _cgl.disable(glDepthTest);
        }
        break;
      case cDepthFunc:
        _cgl.depthFunc(val as int);
        break;
      case cStencilFunc:
        final TheStencilFunction sfun = val as TheStencilFunction;
        if (sfun.func == glInvalidValue) {
          _cgl.disable(glStencilTest);
        } else {
          _cgl.enable(glStencilTest);
          _cgl.stencilFunc(sfun.func, sfun.value, sfun.mask);
        }
        break;
      case cStencilOp:
        final TheStencilOp op = val as TheStencilOp;
        _cgl.stencilOp(op.fail, op.zfail, op.zpass);
        break;
      case cDepthWrite:
        _cgl.depthMask(val as bool);
        break;
      case cBlendEquation:
        final TheBlendEquation beq = val as TheBlendEquation;
        if (beq.equation == glInvalidValue) {
          _cgl.disable(glBlend);
        } else {
          _cgl.enable(glBlend);
          _cgl.blendFunc(beq.srcFactor, beq.dstFactor);
          _cgl.blendEquation(beq.equation);
        }
        break;
      case cColorWrite:
        final List<bool> bb = val as List<bool>;
        _cgl.colorMask(bb[0], bb[1], bb[2], bb[3]);
        break;
      case cStencilWrite:
        _cgl.stencilMask(val as int);
        break;

      default:
        assert(false, "unknown control canonical $canonical");
    }
  }

  void _setUniform(String group, String canonical, Object val) {
    // enable only for debug
    if (_uniformsInitialized.containsKey(canonical)) {
      logError(
        "$name:  $canonical : group [$group] overwrites [$canonical] (${_uniformsInitialized[canonical]})",
      );
    }
    _uniformsInitialized[canonical] = group;

    // Note, we could make this smarter and skip
    // overwriting values with the same values;
    ShaderVarDesc desc = retrieveShaderVarDesc(canonical);
    assert(_uniformLocations.containsKey(canonical));
    GlUniformLocation l = _uniformLocations[canonical]!;
    switch (desc.type) {
      case varTypeInt:
        if (desc.arraySize == 0) {
          _cgl.uniform1i(l, val as int);
        } else if (val is Int32List) {
          _cgl.uniform1iv(l, val);
        }
        break;
      case varTypeFloat:
        if (desc.arraySize == 0) {
          _cgl.uniform1f(l, (val as num).toDouble());
        } else if (val is Float32List) {
          _cgl.uniform1fv(l, val);
        }
        break;
      case varTypeMat4:
        if (desc.arraySize == 0) {
          _cgl.uniformMatrix4fv(l, false, (val as vm.Matrix4).storage);
        } else if (val is Float32List) {
          _cgl.uniformMatrix4fv(l, false, val);
        } else {
          assert(false, "bad unform: $canonical");
        }
        break;
      case varTypeMat3:
        if (desc.arraySize == 0) {
          _cgl.uniformMatrix3fv(l, false, (val as vm.Matrix3).storage);
        } else if (val is Float32List) {
          _cgl.uniformMatrix3fv(l, false, val);
        } else {
          assert(false, "bad unform: $canonical");
        }
        break;
      case varTypeVec4:
        if (desc.arraySize == 0) {
          _cgl.uniform4fv(l, (val as vm.Vector4).storage);
        } else {
          _cgl.uniform4fv(l, val as Float32List);
        }
        break;
      case varTypeVec3:
        if (desc.arraySize == 0) {
          _cgl.uniform3fv(l, (val as vm.Vector3).storage);
        } else {
          _cgl.uniform3fv(l, val as Float32List);
        }
        break;
      case varTypeVec2:
        if (desc.arraySize == 0) {
          _cgl.uniform2fv(l, (val as vm.Vector2).storage);
        } else {
          _cgl.uniform2fv(l, val as Float32List);
        }
        break;
      case varTypeSampler2D:
      case varTypeSampler2DShadow:
        _cgl.activeTexture(glTexture0 + _nextTextureUnit);
        _cgl.bindTexture(glTexture2D, (val as Texture).getTexture());
        _cgl.uniform1i(l, _nextTextureUnit);
        _nextTextureUnit++;
        break;
      case varTypeSamplerCube:
        assert(canonical == uCubeTexture);
        _cgl.activeTexture(glTexture0 + _nextTextureUnit);
        _cgl.bindTexture(glTextureCubeMap, (val as Texture).getTexture());
        _cgl.uniform1i(l, _nextTextureUnit);
        _nextTextureUnit++;
        break;
      default:
        print("Error: unknow uniform type: ${desc.type}");
        assert(false);
    }
  }

  List<String> uninitializedInputs() {
    if (_uniformsInitialized.length == _uniformLocations.length &&
        _attributesInitialized.length == _attributes.length) {
      return [];
    }
    List<String> out = [];
    for (String u in _uniformLocations.keys) {
      if (!_uniformsInitialized.containsKey(u)) out.add(u);
    }
    for (String u in _attributes) {
      if (!_attributesInitialized.contains(u)) out.add(u);
    }
    return out;
  }

  void _activateUniforms(String group, Map<String, Object> inputs) {
    int count = 0;
    final DateTime start = DateTime.now();

    for (String canonical in inputs.keys) {
      switch (canonical.codeUnitAt(0)) {
        case prefixUniform:
          if (_hasUniform(canonical)) {
            _setUniform(group, canonical, inputs[canonical]!);
            ++count;
          }
          break;
        case prefixControl:
          _setControl(canonical, inputs[canonical]!);
          ++count;
          break;
      }
    }
    final Duration delta = DateTime.now().difference(start);
    logDebug("setting $count var in $delta");
  }

  void draw(
    MeshData md,
    List<UniformGroup> uniforms, [
    List<DrawStats>? stats,
  ]) {
    final DateTime start = DateTime.now();
    _cgl.useProgram(_program);
    _clearState();

    // TODO: put this behind a flag
    _uniformsInitialized.clear();
    bool haveSeenMaterial = false;
    for (UniformGroup u in uniforms) {
      _activateUniforms(u.name, u.getUniforms());
      if (u is Material) {
        assert(
          !haveSeenMaterial,
          "in program $name: multiple materials specified",
        );
        haveSeenMaterial = true;
      }
    }

    _attributesInitialized.clear();
    for (String a in md.getAttributes()) {
      _attributesInitialized.add(a);
    }
    if (debug) {
      print(
        "[$name] draw points: ${md.drawMode} instances${md.getNumInstances()}",
      );
    }
    // TODO: put this behind a flag
    List<String> uninitialized = uninitializedInputs();
    if (uninitialized.isNotEmpty) {
      String mesg =
          "$name mesh:${md.name} mode:${md.drawMode}: uninitialized inputs: $uninitialized";
      logError(mesg);
      //throw mesg;
    }

    md.activate();
    bool hasTransforms = _shaderObjectV.transformVars.isNotEmpty;
    _cgl.draw(
      md.drawMode,
      md.getNumItems(),
      md.elementArrayBufferType,
      0,
      md.getNumInstances(),
      hasTransforms,
    );
    if (debug) print(_cgl.getProgramInfoLog(_program));
    if (stats != null) {
      stats.add(
        DrawStats(
          name,
          md.getNumInstances(),
          md.getNumItems(),
          md.drawMode,
          DateTime.now().difference(start),
        ),
      );
    }
  }
}
