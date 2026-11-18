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

/// A GPU program with an API to invoke it. Owns the compiled program, but borrows
/// meshes, materials and textures. Call [dispose] after use.
/// After disposal, drawing, mesh creation and [uninitializedInputs] throw
/// [StateError]. Shader metadata, compatibility queries and [getContext] remain
/// available; they do not imply that the program is still usable.
class RenderProgram extends NamedEntity {
  RenderProgram(super.name, this._cgl, this._shaderObjectV, this._shaderObjectF)
    : _attributes = Set.from(_shaderObjectV.attributeVars),
      attributeLayout = MeshAttributeLayout(
        _shaderObjectV.getAttributeLayoutMap(),
      ) {
    if (_shaderObjectV.stage != ShaderStage.vertex ||
        _shaderObjectF.stage != ShaderStage.fragment) {
      throw ArgumentError(
        'RenderProgram requires a vertex shader and a fragment shader',
      );
    }
    if (_shaderObjectV.shader == null || _shaderObjectF.shader == null) {
      throw StateError('RenderProgram requires completed shader bodies');
    }
    _program = _cgl.compileWholeProgram(
      _shaderObjectV.shader!,
      _shaderObjectF.shader!,
      _shaderObjectV.transformVars,
    );
    try {
      for (String v in {
        ..._shaderObjectV.uniformVars,
        ..._shaderObjectF.uniformVars,
      }) {
        final location = _cgl.getUniformLocation(_program!, v);
        // The linker can optimize out unused uniforms. Only active locations
        // need uploads and initialization checks.
        if (location != null) {
          _uniformLocations[v] = location;
        }
      }
    } catch (_) {
      _cleanupAfterFailure([dispose]);
      rethrow;
    }
  }

  /// Creates a program from two completed shader descriptions.
  RenderProgram.create({
    required String name,
    required ChronosGL context,
    required ShaderObject vertexShader,
    required ShaderObject fragmentShader,
  }) : this(name, context, vertexShader, fragmentShader);

  final ChronosGL _cgl;
  final ShaderObject _shaderObjectV;
  final ShaderObject _shaderObjectF;
  GlProgram? _program;

  final Set<String> _attributes;
  final MeshAttributeLayout attributeLayout;
  final Map<String, GlUniformLocation> _uniformLocations = {};
  final Map<String, String> _uniformsInitialized = {};
  final Set<String> _attributesInitialized = <String>{};

  int _nextTextureUnit = 0;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('RenderProgram $name has been disposed');
  }

  /// Requests deletion of the program exactly once and clears runtime state.
  /// WebGL defers deletion of a current program until another program is bound.
  /// Meshes created by [makeMeshData] remain owned by the caller.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    final program = _program!;
    _program = null;
    _uniformLocations.clear();
    _uniformsInitialized.clear();
    _attributesInitialized.clear();
    _clearState();
    _cgl.deleteProgram(program);
  }

  ShaderObject get shaderObjectV => _shaderObjectV;

  ShaderObject get shaderObjectF => _shaderObjectF;

  int getTransformBindingIndex(String canonical) {
    return _shaderObjectV.getTransformBindingIndex(canonical);
  }

  /// Creates an empty owned mesh with this program's immutable layout.
  GpuMesh makeGpuMesh(String name, int drawMode) {
    _checkNotDisposed();
    return GpuMesh._withLayout(name, _cgl, drawMode, attributeLayout);
  }

  /// Compatibility wrapper for [makeGpuMesh].
  MeshData makeMeshData(String name, int drawMode) =>
      makeGpuMesh(name, drawMode);

  /// If you want to re-use meshes across programs you can use
  /// this predicate to assert that two programs are compatible.
  bool hasCompatibleAttributesTo(RenderProgram other) {
    return identical(_cgl, other._cgl) &&
        attributeLayout.supplies(other.attributeLayout) &&
        other.attributeLayout.supplies(attributeLayout);
  }

  /// If you want to re-use meshes across programs you can use
  /// this predicate to assert that any mesh for `other` will work
  /// for `this`.
  bool hasDownwardCompatibleAttributesTo(RenderProgram other) {
    return identical(_cgl, other._cgl) &&
        other.attributeLayout.supplies(attributeLayout);
  }

  void _clearState() {
    _nextTextureUnit = 0;
  }

  ChronosGL getContext() => _cgl;

  bool _hasUniform(String canonical) {
    return _uniformLocations.containsKey(canonical);
  }

  void _validateControl(String canonical, Object value) {
    final valid = switch (canonical) {
      cDepthTest || cDepthWrite => value is bool,
      cDepthFunc || cStencilWrite => value is int,
      cStencilFunc => value is TheStencilFunction,
      cStencilOp => value is TheStencilOp,
      cBlendEquation => value is TheBlendEquation,
      cColorWrite => value is List<bool> && value.length == 4,
      _ => throw UnsupportedError('Unknown rendering control $canonical'),
    };
    if (!valid) {
      throw ArgumentError.value(
        value,
        canonical,
        'Invalid rendering control value',
      );
    }
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
        throw UnsupportedError('Unknown rendering control $canonical');
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
    final l = _uniformLocations[canonical];
    if (l == null) throw StateError('Uniform $canonical is not active');
    if (!_matchesUniformType(desc, val)) {
      throw ArgumentError.value(val, canonical, 'Expected GLSL ${desc.type}');
    }
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
          throw ArgumentError.value(val, canonical, 'Expected Float32List');
        }
        break;
      case varTypeMat3:
        if (desc.arraySize == 0) {
          _cgl.uniformMatrix3fv(l, false, (val as vm.Matrix3).storage);
        } else if (val is Float32List) {
          _cgl.uniformMatrix3fv(l, false, val);
        } else {
          throw ArgumentError.value(val, canonical, 'Expected Float32List');
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
        _cgl.activeTexture(glTexture0 + _nextTextureUnit);
        _cgl.bindTexture(glTextureCubeMap, (val as Texture).getTexture());
        _cgl.uniform1i(l, _nextTextureUnit);
        _nextTextureUnit++;
        break;
      default:
        throw UnsupportedError('Unsupported uniform type ${desc.type}');
    }
  }

  List<String> uninitializedInputs() {
    _checkNotDisposed();
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
      if (canonical.isEmpty) {
        throw ArgumentError('Uniform name must not be empty');
      }
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

  void draw(GpuMesh md, List<UniformGroup> uniforms, [List<DrawStats>? stats]) {
    _checkNotDisposed();
    md._checkNotDisposed();
    if (!md.isCompatibleWith(this)) {
      throw ArgumentError(
        'GpuMesh ${md.name} has an incompatible context or attribute layout for $name',
      );
    }
    if (uniforms.whereType<Material>().length > 1) {
      throw ArgumentError('RenderProgram $name accepts at most one Material');
    }
    final DateTime start = DateTime.now();
    // Resolve each group once: getUniforms() can compute values on demand.
    // Validate controls and active uniforms before changing WebGL or draw state.
    // Optimized-out uniforms are deliberately ignored, just as during upload.
    final inputs = [
      for (final group in uniforms) Map<String, Object>.of(group.getUniforms()),
    ];
    _checkNotDisposed();
    md._checkNotDisposed();
    for (final values in inputs) {
      for (final entry in values.entries) {
        if (entry.key.isEmpty) {
          throw ArgumentError('Uniform name must not be empty');
        }
        if (entry.key.codeUnitAt(0) == prefixControl) {
          _validateControl(entry.key, entry.value);
          continue;
        }
        if (!_hasUniform(entry.key)) continue;
        final desc = retrieveShaderVarDesc(entry.key);
        final type = desc.type;
        if (!_matchesUniformType(desc, entry.value)) {
          throw ArgumentError.value(
            entry.value,
            entry.key,
            'Expected GLSL $type',
          );
        }
        if (type == varTypeSampler2D ||
            type == varTypeSampler2DShadow ||
            type == varTypeSamplerCube) {
          (entry.value as Texture)._checkNotDisposed();
        }
      }
    }
    _cgl.useProgram(_program!);
    _clearState();

    _uniformsInitialized.clear();
    for (int i = 0; i < uniforms.length; ++i) {
      final u = uniforms[i];
      _activateUniforms(u.name, inputs[i]);
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
    if (debug) print(_cgl.getProgramInfoLog(_program!));
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
