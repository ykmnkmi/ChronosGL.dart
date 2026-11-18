part of 'lib.dart';

final vm.Vector3 _up = vm.Vector3(0.0, 1.0, 0.0);
final vm.Vector3 _up2 = vm.Vector3(0.0, 0.0, 1.0);

/// represents a light source with helpers for
/// light and shadow computation.
/// **Light** is NOT a **UniformGroup**. But several **Lights**
/// can be added to an **Illumination** object which is
/// a **UnformGroup*.
abstract class Light extends NamedEntity {
  Light(super.name, this.type, vm.Vector3 diffuse, vm.Vector3 specular) {
    colorDiffuse.setFrom(diffuse);
    colorSpecular.setFrom(specular);
  }

  final int type;
  final vm.Vector3 colorDiffuse = vm.Vector3.zero();
  final vm.Vector3 colorSpecular = vm.Vector3.zero();

  void extractInfo(Float32List m, int offset);

  vm.Matrix4 extractShadowProjViewMatrix();
}

/// light is emanating from a single point in all directions
class PointLight extends Light {
  /// Position and range use caller-defined world units; colors are RGB values.
  PointLight.named({
    required String name,
    required vm.Vector3 position,
    required vm.Vector3 diffuse,
    required vm.Vector3 specular,
    required double range,
  }) : this(name, position, diffuse, specular, range);

  PointLight(
    String name,
    this.pos,
    vm.Vector3 colorDiffuse,
    vm.Vector3 colorSpecular,
    this.range,
  ) : super(name, lightTypePoint, colorDiffuse, colorSpecular);

  vm.Vector3 pos;

  double range;

  // Must be in sync with UnpackPointLightInfo
  @override
  void extractInfo(Float32List m, int o) {
    m[o + 0] = pos.x;
    m[o + 1] = pos.y;
    m[o + 2] = pos.z;
    //
    m[o + 8] = colorDiffuse.x;
    m[o + 9] = colorDiffuse.y;
    m[o + 10] = colorDiffuse.z;
    //
    m[o + 12] = colorSpecular.x;
    m[o + 13] = colorSpecular.y;
    m[o + 14] = colorSpecular.z;
    //
    m[o + 7] = range;
  }

  @override
  vm.Matrix4 extractShadowProjViewMatrix() {
    throw UnsupportedError('Point-light shadow projection requires cube maps');
  }

  @override
  String toString() {
    return "PL: p:$pos  r:$range";
  }
}

/// Conceptually a directional light is emanating from a infinitely large source
/// at infinite distance.
class DirectionalLight extends Light {
  /// shadowExtent is the positive half-size of the shadow volume in world units.
  DirectionalLight.named({
    required String name,
    required vm.Vector3 direction,
    required vm.Vector3 diffuse,
    required vm.Vector3 specular,
    required double shadowExtent,
  }) : this(name, direction, diffuse, specular, shadowExtent);

  DirectionalLight(
    String name,
    this.dir,
    vm.Vector3 colorDiffuse,
    vm.Vector3 colorSpecular,
    this.dim,
  ) : super(name, lightTypeDirectional, colorDiffuse, colorSpecular);

  final vm.Vector3 dir;
  final double dim;

  final vm.Matrix4 _projViewMat = vm.Matrix4.zero();
  final vm.Matrix4 _tmpMat = vm.Matrix4.zero();

  // Must be in sync with UnpackDirectionalLightInfo
  @override
  void extractInfo(Float32List m, int o) {
    m[o + 4] = dir.x;
    m[o + 5] = dir.y;
    m[o + 6] = dir.z;
    //
    m[o + 8] = colorDiffuse.x;
    m[o + 9] = colorDiffuse.y;
    m[o + 10] = colorDiffuse.z;
    //
    m[o + 12] = colorSpecular.x;
    m[o + 13] = colorSpecular.y;
    m[o + 14] = colorSpecular.z;
  }

  /// Uses a symmetric orthographic volume with signed depth [-dim, dim].
  /// Throws [ArgumentError] if the projection bounds are invalid.
  @override
  vm.Matrix4 extractShadowProjViewMatrix() {
    OrthographicProjection(
      left: -dim,
      right: dim,
      bottom: -dim,
      top: dim,
      near: -dim,
      far: dim,
    ).copyMatrixInto(_projViewMat);

    vm.Vector3 up = (dir.x == 0.0 && dir.z == 0.0) ? _up2 : _up;
    vm.setViewMatrix(_tmpMat, vm.Vector3.zero(), dir, up);
    _projViewMat.multiply(_tmpMat);
    return _projViewMat;
  }

  @override
  String toString() {
    return "DL: p:$dir";
  }
}

/// a cone of directional light is emanating from a point
class SpotLight extends Light {
  /// Half-cone angle uses radians; position, range and clipping use world units.
  /// spotFocus is dimensionless. Shadow projection uses a 2.1 * angleRadians FOV.
  SpotLight.named({
    required String name,
    required vm.Vector3 position,
    required vm.Vector3 direction,
    required vm.Vector3 diffuse,
    required vm.Vector3 specular,
    required double range,
    required double angleRadians,
    required double spotFocus,
    required double near,
    required double far,
  }) : this(
         name,
         position,
         direction,
         diffuse,
         specular,
         range,
         angleRadians,
         spotFocus,
         near,
         far,
       );

  SpotLight(
    String name,
    this.pos,
    this.dir,
    vm.Vector3 colorDiffuse,
    vm.Vector3 colorSpecular,
    this.range,
    this.angle,
    this._spotFocus,
    this._near,
    this._far,
  ) : super(name, lightTypeSpot, colorDiffuse, colorSpecular);

  vm.Vector3 pos;
  vm.Vector3 dir;
  double range;
  double angle;

  //
  final double _spotFocus;

  //
  final double _aspect = 1.0;
  final double _near;
  final double _far;
  final vm.Matrix4 _m1 = vm.Matrix4.zero();
  final vm.Matrix4 _m2 = vm.Matrix4.zero();

  // Must be in sync with UnpackSpotLightInfo
  @override
  void extractInfo(Float32List m, int o) {
    m[o + 0] = pos.x;
    m[o + 1] = pos.y;
    m[o + 2] = pos.z;
    //
    m[o + 4] = dir.x;
    m[o + 5] = dir.y;
    m[o + 6] = dir.z;
    //
    m[o + 8] = colorDiffuse.x;
    m[o + 9] = colorDiffuse.y;
    m[o + 10] = colorDiffuse.z;
    //
    m[o + 12] = colorSpecular.x;
    m[o + 13] = colorSpecular.y;
    m[o + 14] = colorSpecular.z;
    //
    m[o + 7] = range;
    m[o + 11] = math.cos(angle);
    m[o + 15] = _spotFocus;
  }

  /// Uses the padded full cone angle `2.1 * angle` as the vertical FOV.
  /// Throws [ArgumentError] if the FOV or clipping distances are invalid.
  @override
  vm.Matrix4 extractShadowProjViewMatrix() {
    vm.Vector3 up = (dir.x == 0.0 && dir.z == 0.0) ? _up2 : _up;

    vm.setViewMatrix(_m1, pos, dir + pos, up);
    // 2.1 = 2.0 + epsilon
    PerspectiveProjection(
      fovYRadians: 2.1 * angle,
      aspectRatio: _aspect,
      near: _near,
      far: _far,
    ).copyMatrixInto(_m2);
    _m2.multiply(_m1);
    return _m2;
  }

  @override
  String toString() {
    return "SL: p:$pos  d:$dir  r:$range  a:$angle";
  }
}

/*
// TODO: add proper support for this
class HemisphericalLight implements Light {
  vm.Vector3 _dir;
  vm.Vector3 _colDiffuse;
  vm.Vector3 _colSpecular;
  vm.Vector3 _colGround;

  HemisphericalLight(
      vm.Vector3 dir, this._colDiffuse, this._colGround, this._colSpecular);

  @override
  void extractInfo(Float32List m) {
    assert(false, "NYI");
  }

  @override
  void ExtractShadowViewMatrix(Float32List m) {
    assert(false, "NYI");
  }
}
*/

/// represents a collection of Lights.
class Illumination extends UniformGroup {
  Illumination() : super("illumination");

  final List<Light> _lights = [];

  // There can be up to  kMaxLights
  // Each light is represented by a 4x4 matrix and a type
  // type == 0.0 means the light is not used.
  final Float32List _lightDescs = Float32List(16 * kMaxLights);
  final Float32List _lightTypes = Float32List(kMaxLights);

  void addLight(Light l) {
    if (_lights.length >= kMaxLights) {
      throw StateError('Illumination supports at most $kMaxLights lights');
    }
    _lights.add(l);
  }

  static void _setLightInfo(
    Float32List descs,
    Float32List types,
    List<Light> lights,
  ) {
    // maybe only do this as needed
    descs.fillRange(0, descs.length, 0.0);
    types.fillRange(0, types.length, lightTypeInvalid + 0.0);
    int n = 0;
    for (Light l in lights) {
      if (l.enabled) {
        l.extractInfo(descs, n * 16);
        types[n] = l.type + 0.0;
        n++;
      }
    }
  }

  @override
  Map<String, Object> getUniforms() {
    _setLightInfo(_lightDescs, _lightTypes, _lights);
    forceUniform(uLightDescs, _lightDescs);
    forceUniform(uLightTypes, _lightTypes);
    return super.getUniforms();
  }
}
