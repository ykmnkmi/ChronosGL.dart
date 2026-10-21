part of 'lib.dart';

/// provides an Orthographic Perspective Matrix
class Orthographic extends UniformGroup {
  // d = "down", up is computed dynamically based on height & width
  Orthographic(this._camera, this._l, this._r, this._d, this._f, this._b)
    : super("othrogrpahic") {
    update();
  }

  final Spatial _camera;
  final vm.Matrix4 _proj = vm.Matrix4.zero();
  final vm.Matrix4 _viewMatrix = vm.Matrix4.zero();
  final vm.Matrix4 _projViewMatrix = vm.Matrix4.identity();
  double _aspect = 1.0;
  final double _l;
  final double _r;
  final double _d;
  final double _f;
  final double _b;

  @override
  Map<String, Object> getUniforms() {
    _camera.getViewMatrix(_viewMatrix);
    _projViewMatrix.setFrom(_proj);
    _projViewMatrix.multiply(_viewMatrix);
    forceUniform(uPerspectiveViewMatrix, _projViewMatrix);
    return _uniforms;
  }

  void update() {
    double w = _r - _l;
    double h = w / _aspect;
    vm.setOrthographicMatrix(_proj, _l, _r, _d, _d + h, _f, _b);
  }

  void adjustAspect(int w, int h) {
    double a = w / h;
    if (_aspect == a) return;
    _aspect = a;
    update();
  }
}

/// provides the **Input** for perspective projection, i.e.
/// the uPerspectiveViewMatrix Uniform which also requires a **Camera**
/// for view matrix.
class Perspective extends UniformGroup {
  Perspective(
    this._camera,
    this._near,
    this._far, [
    String name = "perspective",
  ]) : super(name) {
    update();
  }

  Spatial _camera;
  double _fov = 50.0; // horizontal fov in deg  divided by 2
  double _aspect = 1.0;
  final double _near;
  final double _far;
  final vm.Matrix4 _perspectiveViewMatrix = vm.Matrix4.identity();
  final vm.Matrix4 _viewMatrix = vm.Matrix4.identity();
  final vm.Matrix4 _mat = vm.Matrix4.zero();

  void adjustAspect(int w, int h) {
    double a = w / h;

    if (_aspect == a) return;
    _aspect = a;
    update();
  }

  void update() {
    vm.setPerspectiveMatrix(_mat, _fov * math.pi / 180.0, _aspect, _near, _far);
  }

  void updateFov(double fov) {
    if (_fov == fov) return;
    _fov = fov;
    update();
  }

  void updateCamera(Spatial cam) {
    _camera = cam;
  }

  @override
  Map<String, Object> getUniforms() {
    forceUniform(uEyePosition, _camera.getEyePosition());
    _camera.getViewMatrix(_viewMatrix);
    _perspectiveViewMatrix.setFrom(_mat);
    _perspectiveViewMatrix.multiply(_viewMatrix);
    forceUniform(uPerspectiveViewMatrix, _perspectiveViewMatrix);
    return _uniforms;
  }
}
