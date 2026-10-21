part of 'lib.dart';

final int rightX = 0, rightY = 4, rightZ = 8;
final int upX = 1, upY = 5, upZ = 9;
final int backX = 2, backY = 6, backZ = 10;
final int posX = 12, posY = 13, posZ = 14;

/// is a base class for object that need to be transformed, e.g.
/// moved, scaled, rotated. It is also used as a Camera abstraction.
class Spatial extends NamedEntity {
  Spatial(super.name);
  // position and rotation
  // the idea to use a matrix4 for this might be problematic,
  // as the values degenerate over time.
  // Might be better to use Quaternions anyways
  // regular lookAt calls could "repair" the matrix
  // (or an optimized variant of lookAt).
  final vm.Matrix4 transform = vm.Matrix4.identity();

  // temp variables to avoid creating new objects:
  // CHANGES TO THE VALUES WILL NOT IMPACT THE MATRIX AND MIGHT BE SHARED WITH OTHER USERS
  final vm.Vector3 _pos = vm.Vector3.zero();
  final vm.Vector3 _back = vm.Vector3.zero();
  final vm.Vector3 _up = vm.Vector3.zero();
  final vm.Vector3 _right = vm.Vector3.zero();

  void getViewMatrix(vm.Matrix4 m) {
    m.setFrom(transform);
  }

  vm.Vector3 getEyePosition() {
    return getPos();
  }

  vm.Vector3 getPos() {
    _pos[0] = transform[posX];
    _pos[1] = transform[posY];
    _pos[2] = transform[posZ];
    return _pos;
  }

  // get the values from column 2. They represent the trail direction of this matrx
  // return ReadOnly vec3
  vm.Vector3 getBack() {
    _back[0] = transform[backX];
    _back[1] = transform[backY];
    _back[2] = transform[backZ];
    return _back;
  }

  // get the values from column 1. They represent the up vector of this matrx
  // return ReadOnly vec3
  vm.Vector3 getUp() {
    _up[0] = transform[upX];
    _up[1] = transform[upY];
    _up[2] = transform[upZ];
    return _up;
  }

  // get the values from column 0. They represent the right vector of this matrx
  // return ReadOnly vec3
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
    transform.rotate(getRight(), -amount);
  }

  void lookDown(double amount) {
    transform.rotate(getRight(), amount);
  }

  void rollLeft(double amount) {
    transform.rotate(getBack(), -amount);
  }

  void rollRight(double amount) {
    transform.rotate(getBack(), amount);
  }

  void lookLeft(double amount) {
    transform.rotate(getUp(), -amount);
  }

  void lookRight(double amount) {
    transform.rotate(getUp(), amount);
  }

  void lookAt(vm.Vector3 target, [vm.Vector3? up]) {
    up ??= vm.Vector3(0.0, 1.0, 0.0);
    vm.setViewMatrix(transform, getPos(), target, up);
  }
}
