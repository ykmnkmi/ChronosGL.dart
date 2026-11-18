/// CPU-only shader interface descriptions and canonical variable metadata.
library;

/// The programmable pipeline stage described by a [ShaderObject].
enum ShaderStage { vertex, fragment }

/// A shader compiler or program linker failure, including the driver log.
class ShaderCompilationException implements Exception {
  const ShaderCompilationException(this.message, {this.stage, this.source});

  final String message;

  /// Null for a failure while linking a complete program.
  final ShaderStage? stage;
  final String? source;

  @override
  String toString() =>
      'ShaderCompilationException'
      '${stage == null ? " (link)" : " (${stage!.name})"}: $message';
}

/// A uniform name paired with the Dart type accepted by typed setters.
///
/// Canonical strings remain available for GLSL interpolation and legacy APIs.
/// Register custom names using [introduceNewShaderVar] before using their key.
/// Values and shader metadata are checked when a group accepts this key.
class UniformKey<T extends Object> {
  const UniformKey(this.name);

  final String name;

  void validateValue(Object value) {
    if (name.isEmpty || !name.startsWith('u')) {
      throw ArgumentError.value(name, 'name', 'Expected a uniform name');
    }
    retrieveShaderVarDesc(name);
    if (value is! T) {
      throw ArgumentError.value(value, name, 'Expected $T');
    }
  }

  @override
  String toString() => name;
}

const int kMaxLights = 4;
const int kMaxBones = 128;

const int lightTypeInvalid = 0;
const int lightTypeDirectional = 1;
const int lightTypeSpot = 2;
const int lightTypePoint = 3;

const String lightTypeInvalidFloat = "$lightTypeInvalid.0";
const String lightTypeDirectionalFloat = "$lightTypeDirectional.0";
const String lightTypeSpotFloat = "$lightTypeSpot.0";
const String lightTypePointFloat = "$lightTypePoint.0";

const String varTypeFloat = "float";
const String varTypeVec2 = "vec2";
const String varTypeVec3 = "vec3";
const String varTypeVec4 = "vec4";

const String varTypeMat3 = "mat3";
const String varTypeMat4 = "mat4";
const String varTypeUvec4 = "uvec4";
const String varTypeUvec3 = "uvec3";
const String varTypeUvec2 = "uvec2";
const String varTypeSampler2D = "sampler2D";
const String varTypeSampler2DShadow = "sampler2DShadow";
const String varTypeSamplerCube = "samplerCube";
const String varTypeInt = "int";
const String varTypeIndex = "index";

class ShaderVarDesc {
  const ShaderVarDesc(this.type, this.purpose, {this.arraySize = 0});

  final String type;
  final String purpose;
  final int arraySize;

  int getSize() {
    switch (type) {
      case varTypeFloat:
        return 1;
      case varTypeVec2:
        return 2;
      case varTypeVec3:
      case varTypeUvec3:
        return 3;
      case varTypeVec4:
      case varTypeUvec4:
        return 4;
      case varTypeUvec2:
        return 2;
      default:
        throw UnsupportedError(
          'No vertex attribute width for shader type $type',
        );
    }
  }

  bool isScalarTypeFloat() {
    switch (type) {
      case varTypeFloat:
      case varTypeVec2:
      case varTypeVec3:
      case varTypeVec4:
        return true;
      default:
        return false;
    }
  }
}

// Used both as enum and as string. The latter allows for a limited form
// of syntax checking inside shader programs.
const String oFragColor = "oFragColor";
// ===========================================================
// Misc Controls
// ===========================================================
const int prefixControl = 0x63; // 'c;

const String cDepthFunc = "cDepthFunc";
const String cDepthTest = "cDepthTest";
const String cDepthWrite = "cDepthWrite";
const String cBlendEquation = "cBlendEquation";
const String cStencilFunc = "cStencilFunc";
const String cStencilOp = "cStencilOp";
const String cNumItems = "cNumItems";
const String cNumInstances = "cNumInstances";
const String cDrawMode = "cDrawMode";
const String cColorWrite = "cColorWrite";
const String cStencilWrite = "cStencilWrite";

// ===========================================================
// TransformFeedback
// ===========================================================

const int prefixTransform = 0x74; // 't';

const String tPosition = "tPosition";
const String tSpeed = "tSpeed";
const String tForce = "tForce";
// ===========================================================
// Attributes
// ===========================================================
const int prefixAttribute = 0x61; // 'a';

const String aColor = "aColor";
const String aColorAlpha = "aColorAlpha";
const String aPosition = "aPosition";
const String aTexUV = "aTexUV";
const String aNormal = "aNormal";
const String aBinormal = "aBinormal";
const String aTangent = "aTangent";
const String aBitangent = "aBitangent";

//
const String aCenter = "aCenter";
// For point sprites
const String aPointSize = "aPointSize";
// For animations
const String aBoneIndex = "aBoneIndex";
const String aBoneWeight = "aBoneWeight";

// ===========================================================
// Instancer
// ===========================================================
const int prefixInstancer = 0x69; // 'i';

const String iaRotation = "iaRotation";
const String iaTranslation = "iaTranslation";
const String iaScale = "iaScale";
const String iaColor = "iaColor";

// ===========================================================
// Varying
// ===========================================================
const String vColor = "vColor";
const String vTexUV = "vTexUV";
const String vLightWeighting = "vLightWeighting";
const String vNormal = "vNormal";
const String vPosition = "vPosition";
const String vCenter = "vCenter";
const String vDepth = "vDepth";

const String vPositionFromLight = "vPositionFromLight";

// ===========================================================
// Uniform
// ===========================================================
const int prefixUniform = 0x75; // 'u';

const String uTransformationMatrix = "uTransformationMatrix";
//const String uModelViewMatrix = "uModelViewMatrix";
//const String uViewMatrix = "uViewMatrix";
const String uNormalMatrix = "uNormalMatrix";
const String uConvolutionMatrix = "uConvolutionMatrix";

const String uPerspectiveViewMatrix = "uPerspectiveViewMatrix";
const String uLightPerspectiveViewMatrix = "uLightPerspectiveViewMatrix";

const String uModelMatrix = "uModelMatrix";

const String uTexture = "uTexture";
const String uCubeTexture = "uCubeTexture";
const String uTexture2 = "uTexture2";
const String uTexture3 = "uTexture3";
const String uTexture4 = "uTexture4";
const String uBumpMap = "uBumpMap";
const String uNormalMap = "uNormalMap";
const String uSpecularMap = "uSpecularMap";
const String uAnimationTable = "uAnimationTable";

const String uDepthMap = "uDepthMap";
const String uShadowMap = "uShadowMap";

const String uTime = "uTime";
const String uColor = "uColor";
const String uColorAlpha2 = "uColorAlpha2";
const String uColorAlpha = "uColorAlpha";
const String uColorEmissive = "uColorEmissive";
const String uColorAmbient = "uAmbientDiffuse";
const String uColorDiffuse = "uColorDiffuse";
const String uColorSpecular = "uColorSpecular";
const String uCameraNear = "uCameraNear";
const String uCameraFar = "uCameraFar";
const String uCanvasSize = "uCanvasSize";
const String uCenter2 = "uCenter2";
const String uPointSize = "uPointSize";
const String uScale = "uScale";
const String uAngle = "uAngle";
const String uFogNear = "uFogNear";
const String uFogFar = "uFogFar";
const String uEyePosition = "uEyePosition";
const String uBoneMatrices = "uBoneMatrices";
const String uBumpScale = "uBumpScale";
const String uNormalScale = "uNormalScale";
const String uCutOff = "uCutOff";
const String uShininess = "uShininess";
const String uOpacity = "uOpacity";
const String uShadowBias = "uShadowBias";
const String uRange = "uRange";
const String uDirection = "uDirection";
const String uThickness = "uThickness";

const String uMaterial = "uMaterial";

const String uLightDescs = "uLightDescs";
const String uLightCount = "uLightCount";
const String uLightTypes = "uLightTypes";

/// This map can be augmented with custom entries via
/// introduceNewShaderVar()
/// All shaders-vars associated with shaders must be in this map.
final Map<String, ShaderVarDesc> _varsDb = {
  // controls
  cBlendEquation: const ShaderVarDesc("", ""),
  cDepthWrite: const ShaderVarDesc("", ""),
  cDepthTest: const ShaderVarDesc("", ""),
  cStencilFunc: const ShaderVarDesc("", ""),

  // transform vars
  tPosition: const ShaderVarDesc(varTypeVec3, ""),
  tSpeed: const ShaderVarDesc(varTypeVec3, ""),
  tForce: const ShaderVarDesc(varTypeVec3, ""),

  // attribute vars
  // This should also contain an alpha channel
  aColor: const ShaderVarDesc(varTypeVec3, "per vertex color"),
  aColorAlpha: const ShaderVarDesc(varTypeVec4, "per vertex color"),
  aPosition: const ShaderVarDesc(varTypeVec3, "vertex coordinates"),
  aTexUV: const ShaderVarDesc(varTypeVec2, "texture uvs"),
  aNormal: const ShaderVarDesc(varTypeVec3, "vertex normals"),
  aBinormal: const ShaderVarDesc(varTypeVec3, "vertex binormals"),
  aCenter: const ShaderVarDesc(varTypeVec4, "for wireframe"),
  aPointSize: const ShaderVarDesc(varTypeFloat, ""),
  aBoneIndex: const ShaderVarDesc(varTypeVec4, ""),
  aBoneWeight: const ShaderVarDesc(varTypeVec4, ""),
  aTangent: const ShaderVarDesc(varTypeVec3, "vertex tangents"),
  aBitangent: const ShaderVarDesc(varTypeVec3, "vertex btangents"),
  iaRotation: const ShaderVarDesc(varTypeVec4, ""),
  iaTranslation: const ShaderVarDesc(varTypeVec3, ""),
  iaScale: const ShaderVarDesc(varTypeFloat, ""),
  iaColor: const ShaderVarDesc(varTypeVec3, ""),

  // Varying
  vColor: const ShaderVarDesc(varTypeVec3, "per vertex color"),
  vTexUV: const ShaderVarDesc(varTypeVec2, ""),
  vLightWeighting: const ShaderVarDesc(varTypeVec3, ""),
  vNormal: const ShaderVarDesc(varTypeVec3, ""),
  vPosition: const ShaderVarDesc(varTypeVec3, "vertex coordinates"),
  vPositionFromLight: const ShaderVarDesc(varTypeVec4, "delta from light"),
  vCenter: const ShaderVarDesc(varTypeVec4, "for wireframe"),
  vDepth: const ShaderVarDesc(varTypeFloat, "depth for shadowmaps"),

  // uniform vars
  uTransformationMatrix: const ShaderVarDesc(varTypeMat4, ""),
  //uModelViewMatrix: const ShaderVarDesc(varTypeMat4, ""),
  uModelMatrix: const ShaderVarDesc(varTypeMat4, ""),
  //uViewMatrix: const ShaderVarDesc(varTypeMat4, ""),
  uNormalMatrix: const ShaderVarDesc(varTypeMat3, ""),
  uConvolutionMatrix: const ShaderVarDesc(varTypeMat3, ""),

  //uPerspectiveMatrix: const ShaderVarDesc(varTypeMat4, ""),
  uPerspectiveViewMatrix: const ShaderVarDesc(varTypeMat4, ""),
  uLightPerspectiveViewMatrix: const ShaderVarDesc(varTypeMat4, ""),

  uShadowMap: const ShaderVarDesc(varTypeSampler2DShadow, ""),

  uTexture: const ShaderVarDesc(varTypeSampler2D, ""),
  uTexture2: const ShaderVarDesc(varTypeSampler2D, ""),
  uTexture3: const ShaderVarDesc(varTypeSampler2D, ""),
  uTexture4: const ShaderVarDesc(varTypeSampler2D, ""),
  uSpecularMap: const ShaderVarDesc(varTypeSampler2D, ""),
  uNormalMap: const ShaderVarDesc(varTypeSampler2D, ""),
  uBumpMap: const ShaderVarDesc(varTypeSampler2D, ""),
  uDepthMap: const ShaderVarDesc(varTypeSampler2D, ""),
  uCubeTexture: const ShaderVarDesc(varTypeSamplerCube, ""),
  uAnimationTable: const ShaderVarDesc(varTypeSampler2D, ""),

  uTime: const ShaderVarDesc(varTypeFloat, "time since program start in sec"),
  uCameraNear: const ShaderVarDesc(varTypeFloat, ""),
  uCameraFar: const ShaderVarDesc(varTypeFloat, ""),
  uFogNear: const ShaderVarDesc(varTypeFloat, ""),
  uFogFar: const ShaderVarDesc(varTypeFloat, ""),
  uPointSize: const ShaderVarDesc(varTypeFloat, ""),
  uScale: const ShaderVarDesc(varTypeFloat, ""),
  uAngle: const ShaderVarDesc(varTypeFloat, ""),
  uCanvasSize: const ShaderVarDesc(varTypeVec2, ""),
  uCenter2: const ShaderVarDesc(varTypeVec2, ""),
  uCutOff: const ShaderVarDesc(varTypeFloat, ""),
  uShininess: const ShaderVarDesc(varTypeFloat, ""),
  uShadowBias: const ShaderVarDesc(varTypeFloat, ""),
  uOpacity: const ShaderVarDesc(varTypeFloat, ""),
  uThickness: const ShaderVarDesc(varTypeFloat, ""),
  uColor: const ShaderVarDesc(varTypeVec3, ""),
  uColorAmbient: const ShaderVarDesc(varTypeVec3, ""),
  uColorEmissive: const ShaderVarDesc(varTypeVec3, ""),
  uColorSpecular: const ShaderVarDesc(varTypeVec3, ""),
  uColorDiffuse: const ShaderVarDesc(varTypeVec3, ""),
  uColorAlpha: const ShaderVarDesc(varTypeVec4, ""),
  uColorAlpha2: const ShaderVarDesc(varTypeVec4, ""),
  uEyePosition: const ShaderVarDesc(varTypeVec3, ""),
  uMaterial: const ShaderVarDesc(varTypeMat4, ""),
  uRange: const ShaderVarDesc(varTypeVec2, ""),
  uDirection: const ShaderVarDesc(varTypeVec2, ""),

  uBoneMatrices: const ShaderVarDesc(varTypeMat4, "", arraySize: kMaxBones),

  uLightDescs: const ShaderVarDesc(varTypeMat4, "", arraySize: kMaxLights),
  uLightCount: const ShaderVarDesc(varTypeFloat, ""),
  uLightTypes: const ShaderVarDesc(varTypeFloat, "", arraySize: kMaxLights),

  uBumpScale: const ShaderVarDesc(varTypeFloat, "for bump maps"),
  uNormalScale: const ShaderVarDesc(varTypeFloat, "for normal maps"),
};

void introduceNewShaderVar(String canonical, ShaderVarDesc desc) {
  if (canonical.isEmpty ||
      !RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(canonical)) {
    throw ArgumentError.value(
      canonical,
      'canonical',
      'Expected a GLSL identifier',
    );
  }
  if (_varsDb.containsKey(canonical)) {
    throw ArgumentError.value(
      canonical,
      'canonical',
      'Duplicate shader variable',
    );
  }
  if (desc.arraySize < 0) {
    throw ArgumentError.value(
      desc.arraySize,
      'arraySize',
      'Must be nonnegative',
    );
  }
  _varsDb[canonical] = desc;
}

ShaderVarDesc retrieveShaderVarDesc(String canonical) {
  return _varsDb[canonical] ??
      (throw ArgumentError.value(
        canonical,
        'canonical',
        'Unknown shader variable',
      ));
}

/// A shader description with an explicit pipeline [stage].
///
/// Add interface variables before setting the source body. Interface collections
/// are read-only; mutation after source generation throws [StateError].
class ShaderObject {
  /// Legacy constructor. Only this compatibility path infers the stage from
  /// attributes; use [ShaderObject.create] for vertex shaders without attributes.
  @Deprecated('Use ShaderObject.create with an explicit ShaderStage')
  ShaderObject(this.name) : _stage = null;

  factory ShaderObject.create({
    required String name,
    required ShaderStage stage,
  }) => switch (stage) {
    ShaderStage.vertex => ShaderObject.vertex(name),
    ShaderStage.fragment => ShaderObject.fragment(name),
  };

  ShaderObject.vertex(this.name) : _stage = ShaderStage.vertex;
  ShaderObject.fragment(this.name) : _stage = ShaderStage.fragment;

  final String name;
  final ShaderStage? _stage;
  ShaderStage get stage =>
      _stage ??
      (_attributeVars.isEmpty ? ShaderStage.fragment : ShaderStage.vertex);

  String? _shader;
  String? get shader => _shader;

  /// Accepts a complete GLSL source once, for callers that generate it elsewhere.
  set shader(String? source) {
    _checkEditable();
    if (source == null || source.trim().isEmpty) {
      throw ArgumentError.value(
        source,
        'source',
        'Shader source must not be empty',
      );
    }
    _shader = source;
  }

  final List<String> _attributeVars = [];
  final List<String> _uniformVars = [];
  final List<String> _varyingVars = [];
  final List<String> _transformVars = [];
  List<String> get attributeVars => List.unmodifiable(_attributeVars);
  List<String> get uniformVars => List.unmodifiable(_uniformVars);
  List<String> get varyingVars => List.unmodifiable(_varyingVars);
  List<String> get transformVars => List.unmodifiable(_transformVars);
  final Map<String, int> _canonicalToLayoutPos = {};

  int getAttributeLayoutPos(String canonical) =>
      _canonicalToLayoutPos[canonical] ??
      (throw ArgumentError.value(canonical, 'canonical', 'Unknown attribute'));

  int getTransformBindingIndex(String canonical) =>
      _transformVars.indexOf(canonical);

  Map<String, int> getAttributeLayoutMap() =>
      Map.unmodifiable(_canonicalToLayoutPos);

  void _checkEditable() {
    if (_shader != null) throw StateError('Shader $name already has a body');
  }

  void _addVars(List<String> names, List<String> destination) {
    _checkEditable();
    final seen = destination.toSet();
    for (final n in names) {
      retrieveShaderVarDesc(n);
      if (!seen.add(n)) {
        throw ArgumentError.value(n, 'names', 'Duplicate shader variable');
      }
    }
    destination.addAll(names);
    destination.sort();
  }

  void addAttributeVars(List<String> names) {
    if (_stage == ShaderStage.fragment) {
      throw UnsupportedError(
        'Fragment shaders cannot declare vertex attributes',
      );
    }
    _addVars(names, _attributeVars);
    for (final n in names) {
      _canonicalToLayoutPos[n] = _canonicalToLayoutPos.length;
    }
  }

  void addUniformVars(List<String> names) => _addVars(names, _uniformVars);
  void addVaryingVars(List<String> names) => _addVars(names, _varyingVars);

  void addTransformVars(List<String> names) {
    if (_stage == ShaderStage.fragment) {
      throw UnsupportedError('Transform feedback requires a vertex shader');
    }
    _addVars(names, _transformVars);
  }

  void setBodyWithMain(List<String> body, {List<String>? prolog}) {
    _checkEditable();
    _shader = _createShader(true, body, prolog);
  }

  void setBody(List<String> body, {List<String>? prolog}) {
    _checkEditable();
    _shader = _createShader(false, body, prolog);
  }

  String _createShader(
    bool addWrapperForMain,
    List<String> body,
    List<String>? prolog,
  ) {
    final isFragmentShader = stage == ShaderStage.fragment;
    final out = <String>[
      "#version 300 es",
      "precision highp float;",
      "precision highp sampler2DShadow;",
      "",
    ];
    for (final a in _attributeVars) {
      final d = retrieveShaderVarDesc(a);
      final pos = getAttributeLayoutPos(a);
      out.add("layout (location=$pos) in ${d.type} $a;");
    }
    out.add("");
    final modifier = isFragmentShader ? "in" : "out";
    if (isFragmentShader) out.add("out vec4 $oFragColor;");
    for (final v in [..._varyingVars, ..._transformVars]) {
      final d = retrieveShaderVarDesc(v);
      out.add("$modifier ${d.type} $v;");
    }
    out.add("");
    for (final v in _uniformVars) {
      final d = retrieveShaderVarDesc(v);
      final suffix = d.arraySize == 0 ? "" : "[${d.arraySize}]";
      out.add("uniform ${d.type} $v$suffix;");
    }
    out.add("");
    if (prolog != null) out.addAll(prolog);
    if (addWrapperForMain) out.add("void main(void) {");
    out.addAll(body);
    if (addWrapperForMain) out.add("}");
    return out.join("\n");
  }
}
