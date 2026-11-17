part of 'lib.dart';

final int rightX = 0, rightY = 1, rightZ = 2;
final int upX = 4, upY = 5, upZ = 6;
final int backX = 8, backY = 9, backZ = 10;
final int posX = 12, posY = 13, posZ = 14;

/// Legacy base for scene objects and cameras.
///
/// New object transforms should use `Transform` from `package:chronosgl/core.dart`.
/// [transform] maps local coordinates to parent coordinates (world coordinates
/// for an unparented camera). [lookAt] preserves its position; [getViewMatrix]
/// writes the inverse into separate storage. The matrix and scratch vectors
/// remain mutable legacy APIs. Prefer `Camera` for a separate position/rotation
/// model. See docs/3.6_CAMERA_POSITION.md for the legacy migration.
class Spatial extends NamedEntity {
  Spatial(super.name);
  // position and rotation
  // the idea to use a matrix4 for this might be problematic,
  // as the values degenerate over time.
  // Might be better to use Quaternions anyways
  // regular lookAt calls could "repair" the matrix
  // (or an optimized variant of lookAt).
  /// Live writable local-to-parent pose; edits immediately affect this object.
  /// Unlike `Transform.matrix` and `Camera.worldMatrix`, this is not a snapshot.
  final vm.Matrix4 transform = vm.Matrix4.identity();

  // temp variables to avoid creating new objects:
  // CHANGES TO THE VALUES WILL NOT IMPACT THE MATRIX AND MIGHT BE SHARED WITH OTHER USERS
  final vm.Vector3 _pos = vm.Vector3.zero();
  final vm.Vector3 _back = vm.Vector3.zero();
  final vm.Vector3 _up = vm.Vector3.zero();
  final vm.Vector3 _right = vm.Vector3.zero();

  /// Copies the inverse world pose into [m], without changing [transform].
  ///
  /// Cameras must be unparented. Throws [StateError] for a singular or nonfinite
  /// inverse, leaving [m] intact. Output storage must not overlap [transform],
  /// even through another Matrix4 or typed-data view; that throws [ArgumentError].
  void getViewMatrix(vm.Matrix4 m) {
    final output = m.storage;
    final pose = transform.storage;
    if (output.buffer == pose.buffer &&
        output.offsetInBytes < pose.offsetInBytes + pose.lengthInBytes &&
        pose.offsetInBytes < output.offsetInBytes + output.lengthInBytes) {
      throw ArgumentError('View output must not overlap the camera transform');
    }
    final view = vm.Matrix4.zero();
    final determinant = view.copyInverse(transform);
    if (determinant == 0 ||
        !determinant.isFinite ||
        view.storage.any((value) => !value.isFinite)) {
      throw StateError('Camera transform has no finite inverse');
    }
    m.setFrom(view);
  }

  /// Eye position in world space for an unparented camera, never view translation.
  /// Returns the borrowed scratch vector from [getPos]; copy it to retain it.
  vm.Vector3 getEyePosition() {
    return getPos();
  }

  /// Borrowed position scratch vector, overwritten by the next position read.
  /// Editing it does not edit the pose; use [setPos] or [setPosFromVec].
  vm.Vector3 getPos() {
    _pos[0] = transform[posX];
    _pos[1] = transform[posY];
    _pos[2] = transform[posZ];
    return _pos;
  }

  /// Local +Z column in parent space, returned in borrowed scratch storage.
  /// Copy to retain it; editing this vector does not edit the pose.
  vm.Vector3 getBack() {
    _back[0] = transform[backX];
    _back[1] = transform[backY];
    _back[2] = transform[backZ];
    return _back;
  }

  /// Local +Y column in parent space, returned in borrowed scratch storage.
  /// Copy to retain it; editing this vector does not edit the pose.
  vm.Vector3 getUp() {
    _up[0] = transform[upX];
    _up[1] = transform[upY];
    _up[2] = transform[upZ];
    return _up;
  }

  /// Local +X column in parent space, returned in borrowed scratch storage.
  /// Copy to retain it; editing this vector does not edit the pose.
  vm.Vector3 getRight() {
    _right[0] = transform[rightX];
    _right[1] = transform[rightY];
    _right[2] = transform[rightZ];
    return _right;
  }

  void setPos(double x, double y, double z) // TODO: make dynamic
  {
    transform[posX] = x;
    transform[posY] = y;
    transform[posZ] = z;
  }
  /*
  void scale(num x, num y, num z) {
    transform[0] *= x;
    transform[5] *= x;
    transform[10] *= x;
  }*/

  void addPos(double x, double y, double z) {
    translate(x, y, z); // alias
  }

  void addPosFromVec(vm.Vector3 vector) {
    translateFromVec(vector); // alias
  }

  void setPosFromVec(vm.Vector3 vector) {
    transform[posX] = vector[0];
    transform[posY] = vector[1];
    transform[posZ] = vector[2];
  }

  void setPosFromSpherical(double radius, double azimuth, double polar) {
    double rcp = radius * math.cos(polar);
    setPos(
      rcp * math.cos(azimuth),
      radius * math.sin(polar),
      rcp * math.sin(azimuth),
    );
  }

  void translate(double x, double y, double z, [double factor = 1.0]) {
    transform[posX] += x * factor;
    transform[posY] += y * factor;
    transform[posZ] += z * factor;
  }

  void translateFromVec(vm.Vector3 vector, [double factor = 1.0]) {
    transform[posX] += vector[0] * factor;
    transform[posY] += vector[1] * factor;
    transform[posZ] += vector[2] * factor;
  }

  void moveForward(double amount) {
    moveBackward(-amount);
  }

  void moveBackward(double amount) {
    transform[posX] += transform[backX] * amount;
    transform[posY] += transform[backY] * amount;
    transform[posZ] += transform[backZ] * amount;
  }

  void moveUp(double amount) {
    transform[posX] += transform[upX] * amount;
    transform[posY] += transform[upY] * amount;
    transform[posZ] += transform[upZ] * amount;
  }

  void moveDown(double amount) {
    moveUp(-amount);
  }

  void moveLeft(double amount) {
    moveRight(-amount);
  }

  void moveRight(double amount) {
    transform[posX] += transform[rightX] * amount;
    transform[posY] += transform[rightY] * amount;
    transform[posZ] += transform[rightZ] * amount;
  }

  void rotX(double angle) {
    transform.rotateX(angle);
  }

  void rotY(double angle) {
    transform.rotateY(angle);
  }

  void rotZ(double angle) {
    transform.rotateZ(angle);
  }

  void lookUp(double amount) {
    rotX(amount);
  }

  void lookDown(double amount) {
    rotX(-amount);
  }

  void rollLeft(double amount) {
    rotZ(amount);
  }

  void rollRight(double amount) {
    rotZ(-amount);
  }

  void lookLeft(double amount) {
    rotY(amount);
  }

  void lookRight(double amount) {
    rotY(-amount);
  }

  /// Points local -Z toward [target], preserving position in parent space.
  ///
  /// For an unparented camera, target and [up] are world-space values. This
  /// replaces the linear part with a rigid orientation (legacy scale/shear is
  /// discarded). Invalid targets/up hints throw [ArgumentError] before mutation,
  /// using the same rules as `Camera.lookAt`. The target is not retained.
  void lookAt(vm.Vector3 target, [vm.Vector3? up]) {
    final position = vm.Vector3.copy(getPos());
    final rotation = normalizedRotation(
      lookAtRotation(position, target, upHint: up),
    );
    transform.setFrom(
      vm.Matrix4.compose(position, rotation, vm.Vector3.all(1)),
    );
  }
}
