part of 'lib.dart';

/// is inherited by almost all other classes in ChronosGL.
/// It mostly exists to help with debugging by giving names to objects.
/// It also provides a simple mechanism for en-/dis-abling objects, though
/// what it means to be disabled will differ from class to class.
abstract class NamedEntity {
  NamedEntity(this.name);

  final String name;
  bool debug = false;
  bool enabled = true;
}

class UnknownEntity extends NamedEntity {
  UnknownEntity() : super("UnknownEntity");
}

final NamedEntity kUnknownEntity = UnknownEntity();

/// is an abstraction for a set of uniforms
///
/// Important subclasses are:
/// * Projection provides a perspective matrix uniform
/// * Material provides color and texture uniforms
/// * Illumination provides uniforms describing light sources
class UniformGroup extends NamedEntity {
  UniformGroup(super.name);

  final Map<String, Object> _uniforms = {};

  void setUniform(String canonical, Object val) {
    if (_uniforms.containsKey(canonical)) {
      throw StateError('Uniform $canonical already set in $name');
    }
    forceUniform(canonical, val);
  }

  void forceUniform(String canonical, Object val) {
    if (canonical.isEmpty) {
      throw ArgumentError.value(canonical, 'canonical', 'Must not be empty');
    }
    _uniforms[canonical] = val;
  }

  bool hasUniform(String canonical) {
    return _uniforms.containsKey(canonical);
  }

  /// Installs a typed uniform after checking both Dart and GLSL types.
  void set<T extends Object>(UniformKey<T> key, T value) {
    _validateTypedUniform(key, value);
    setUniform(key.name, value);
  }

  /// Replaces a typed uniform, or adds it if absent.
  void force<T extends Object>(UniformKey<T> key, T value) {
    _validateTypedUniform(key, value);
    forceUniform(key.name, value);
  }

  T? get<T extends Object>(UniformKey<T> key) {
    final value = getUniforms()[key.name];
    if (value == null) return null;
    _validateTypedUniform(key, value);
    return value as T;
  }

  void _validateTypedUniform(UniformKey<Object> key, Object value) {
    key.validateValue(value);
    final desc = retrieveShaderVarDesc(key.name);
    if (!_matchesUniformType(desc, value)) {
      throw ArgumentError.value(
        value,
        key.name,
        'Expected GLSL ${desc.type}${desc.arraySize > 0 ? "[${desc.arraySize}]" : ""}',
      );
    }
  }

  /// Copies entries into this group through the legacy string-key boundary.
  void addUniforms(Map<String, Object> values) {
    if (values.keys.any((key) => key.isEmpty)) {
      throw ArgumentError('Uniform names must not be empty');
    }
    _uniforms.addAll(values);
  }

  Object? removeUniform(String canonical) => _uniforms.remove(canonical);
  void clearUniforms() => _uniforms.clear();

  /// An immutable snapshot of names and borrowed values.
  Map<String, Object> getUniforms() => Map.unmodifiable(_uniforms);

  @override
  String toString() {
    List<String> out = <String>["{$runtimeType}[$name]"];
    for (String key in _uniforms.keys) {
      out.add("$key: ${_uniforms[key]}");
    }
    return out.join("\n");
  }
}

bool _matchesUniformType(ShaderVarDesc desc, Object value) {
  if (desc.arraySize > 0) {
    final width = switch (desc.type) {
      varTypeFloat || varTypeInt => 1,
      varTypeVec2 => 2,
      varTypeVec3 => 3,
      varTypeVec4 => 4,
      varTypeMat3 => 9,
      varTypeMat4 => 16,
      _ => 0,
    };
    return width > 0 &&
        (desc.type == varTypeInt ? value is Int32List : value is Float32List) &&
        (value as List<num>).isNotEmpty &&
        value.length % width == 0 &&
        value.length <= width * desc.arraySize;
  }
  return switch (desc.type) {
    varTypeFloat => value is num,
    varTypeInt => value is int,
    varTypeVec2 => value is vm.Vector2,
    varTypeVec3 => value is vm.Vector3,
    varTypeVec4 => value is vm.Vector4,
    varTypeMat3 => value is vm.Matrix3,
    varTypeMat4 => value is vm.Matrix4,
    varTypeSampler2D ||
    varTypeSampler2DShadow ||
    varTypeSamplerCube => value is Texture,
    _ => false,
  };
}

/// Typed counterparts of canonical GLSL names. The original string constants
/// remain available for shader source interpolation and migration.
abstract final class UniformKeys {
  static const transformationMatrix = UniformKey<vm.Matrix4>(
    uTransformationMatrix,
  );
  static const modelMatrix = UniformKey<vm.Matrix4>(uModelMatrix);
  static const normalMatrix = UniformKey<vm.Matrix3>(uNormalMatrix);
  static const convolutionMatrix = UniformKey<vm.Matrix3>(uConvolutionMatrix);
  static const perspectiveViewMatrix = UniformKey<vm.Matrix4>(
    uPerspectiveViewMatrix,
  );
  static const lightPerspectiveViewMatrix = UniformKey<vm.Matrix4>(
    uLightPerspectiveViewMatrix,
  );
  static const shadowMap = UniformKey<Texture>(uShadowMap);
  static const texture = UniformKey<Texture>(uTexture);
  static const texture2 = UniformKey<Texture>(uTexture2);
  static const texture3 = UniformKey<Texture>(uTexture3);
  static const texture4 = UniformKey<Texture>(uTexture4);
  static const specularMap = UniformKey<Texture>(uSpecularMap);
  static const normalMap = UniformKey<Texture>(uNormalMap);
  static const bumpMap = UniformKey<Texture>(uBumpMap);
  static const depthMap = UniformKey<Texture>(uDepthMap);
  static const cubeTexture = UniformKey<Texture>(uCubeTexture);
  static const animationTable = UniformKey<Texture>(uAnimationTable);

  /// Time since program start, in seconds.
  static const time = UniformKey<num>(uTime);
  static const cameraNear = UniformKey<num>(uCameraNear);
  static const cameraFar = UniformKey<num>(uCameraFar);
  static const fogNear = UniformKey<num>(uFogNear);
  static const fogFar = UniformKey<num>(uFogFar);

  /// Point size in framebuffer pixels.
  static const pointSize = UniformKey<num>(uPointSize);
  static const scale = UniformKey<num>(uScale);

  /// Angle in radians.
  static const angle = UniformKey<num>(uAngle);

  /// Framebuffer dimensions in physical pixels.
  static const canvasSize = UniformKey<vm.Vector2>(uCanvasSize);
  static const center2 = UniformKey<vm.Vector2>(uCenter2);
  static const cutOff = UniformKey<num>(uCutOff);
  static const shininess = UniformKey<num>(uShininess);
  static const shadowBias = UniformKey<num>(uShadowBias);
  static const opacity = UniformKey<num>(uOpacity);
  static const thickness = UniformKey<num>(uThickness);
  static const color = UniformKey<vm.Vector3>(uColor);
  static const colorAmbient = UniformKey<vm.Vector3>(uColorAmbient);
  static const colorEmissive = UniformKey<vm.Vector3>(uColorEmissive);
  static const colorSpecular = UniformKey<vm.Vector3>(uColorSpecular);
  static const colorDiffuse = UniformKey<vm.Vector3>(uColorDiffuse);
  static const colorAlpha = UniformKey<vm.Vector4>(uColorAlpha);
  static const colorAlpha2 = UniformKey<vm.Vector4>(uColorAlpha2);
  static const eyePosition = UniformKey<vm.Vector3>(uEyePosition);
  static const material = UniformKey<vm.Matrix4>(uMaterial);
  static const range = UniformKey<vm.Vector2>(uRange);
  static const direction = UniformKey<vm.Vector2>(uDirection);
  static const boneMatrices = UniformKey<Float32List>(uBoneMatrices);
  static const lightDescs = UniformKey<Float32List>(uLightDescs);
  static const lightCount = UniformKey<num>(uLightCount);
  static const lightTypes = UniformKey<Float32List>(uLightTypes);
  static const bumpScale = UniformKey<num>(uBumpScale);
  static const normalScale = UniformKey<num>(uNormalScale);
}
