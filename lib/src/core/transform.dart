import 'package:vector_math/vector_math.dart' as vm;

import 'pose_math.dart';

/// An affine local-to-parent transformation, using column vectors.
///
/// Component state composes as `matrix = translation * rotation * scale`.
/// Position is in parent coordinates; local forward is -Z and up is +Y.
/// This component has no parent, world-matrix cache, camera or GPU resources.
/// For a particular scene path, compute `world = parentWorld * matrix`.
///
/// Inputs are copied and getters return independent snapshots. Changes are
/// immediate; no update call is needed. Arbitrary affine matrices (including
/// shear) can be retained with [setMatrix] without a lossy TRS conversion.
class Transform {
  /// Creates a TRS transform, defaulting to identity.
  Transform({
    vm.Vector3? position,
    vm.Quaternion? rotation,
    vm.Vector3? scale,
  }) {
    setTRS(
      position: position ?? vm.Vector3.zero(),
      rotation: rotation ?? vm.Quaternion.identity(),
      scale: scale ?? vm.Vector3.all(1),
    );
  }

  /// Copies an affine local-to-parent matrix. See [setMatrix].
  Transform.fromMatrix(vm.Matrix4 matrix) {
    setMatrix(matrix);
  }

  // vector_math stores these values in Float32List. The tolerance is relative
  // to each linear column, never to translation or a different scale axis.
  static const double _trsTolerance = 1e-5;

  final vm.Matrix4 _matrix = vm.Matrix4.identity();
  vm.Quaternion? _rotation;
  vm.Vector3? _scale;

  /// Whether orientation and scale have a defined TRS representation.
  ///
  /// Explicit TRS state retains its orientation even at zero scale. Imported
  /// singular or sheared matrices have no editable TRS state; use [setTRS] to
  /// replace them explicitly, or continue editing their matrix/position.
  bool get hasTRS => _rotation != null;

  /// Snapshot of the local-to-parent matrix; never a view/projection matrix.
  /// Editing it or its storage has no effect here; use [setMatrix] to commit.
  vm.Matrix4 get matrix => vm.Matrix4.copy(_matrix);

  /// Copies the current local-to-parent matrix into caller-owned storage.
  /// The destination is not retained or refreshed by subsequent edits.
  void copyMatrixInto(vm.Matrix4 out) => out.setFrom(_matrix);

  /// Position in the parent's coordinate system, independent of rotation/scale.
  vm.Vector3 get position => _matrix.getTranslation();

  /// Normalized orientation. Throws [StateError] when [hasTRS] is false.
  vm.Quaternion get rotation {
    _requireTRS();
    return vm.Quaternion.copy(_rotation!);
  }

  /// Signed local scale. Throws [StateError] when [hasTRS] is false.
  vm.Vector3 get scale {
    _requireTRS();
    return vm.Vector3.copy(_scale!);
  }

  /// Unit +X axis in parent space, ignoring scale and reflection.
  vm.Vector3 get right => _direction(vm.Vector3(1, 0, 0));

  /// Unit +Y axis in parent space, ignoring scale and reflection.
  vm.Vector3 get up => _direction(vm.Vector3(0, 1, 0));

  /// Unit +Z axis in parent space, ignoring scale and reflection.
  vm.Vector3 get back => _direction(vm.Vector3(0, 0, 1));

  /// Unit -Z axis in parent space, ignoring scale and reflection.
  vm.Vector3 get forward => _direction(vm.Vector3(0, 0, -1));

  /// Replaces all components, including any previous shear.
  ///
  /// Values must be finite and representable as Float32. Rotation must be
  /// nonzero and is normalized. Zero/negative scale is allowed. Invalid input
  /// throws [ArgumentError] without changing this transform.
  void setTRS({
    required vm.Vector3 position,
    required vm.Quaternion rotation,
    required vm.Vector3 scale,
  }) {
    checkFiniteComponents(position.storage, 'position');
    checkFiniteComponents(scale.storage, 'scale');
    final orientation = normalizedRotation(rotation);
    final next = vm.Matrix4.compose(position, orientation, scale);
    _checkAffine(next);
    _matrix.setFrom(next);
    _rotation = orientation;
    _scale = vm.Vector3.copy(scale);
  }

  /// Copies an affine matrix exactly, including shear, reflection or zero scale.
  ///
  /// The bottom row must be exactly `(0, 0, 0, 1)` and all values finite.
  /// Nonsingular TRS matrices also enable component editing: orthogonality and
  /// reconstruction are checked to 1e-5 relative to each linear column. A
  /// reflected matrix is decomposed with the negative scale on X. Original
  /// scale signs cannot in general be recovered from a matrix alone.
  ///
  /// Sheared/singular matrices remain usable for matrix and parent-position
  /// operations. Component operations throw [StateError] rather than silently
  /// discarding shear or inventing an orientation for a collapsed axis.
  void setMatrix(vm.Matrix4 matrix) {
    _checkAffine(matrix);
    final components = _tryDecompose(matrix);
    _matrix.setFrom(matrix);
    _rotation = components?.$1;
    _scale = components?.$2;
  }

  /// Sets position in parent coordinates without changing the linear matrix.
  void setPosition(double x, double y, double z) {
    final next = vm.Vector3(x, y, z);
    checkFiniteComponents(next.storage, 'position');
    _matrix.setTranslation(next);
  }

  /// Copies a position in parent coordinates.
  void setPositionFromVector(vm.Vector3 value) =>
      setPosition(value.x, value.y, value.z);

  /// Sets orientation, preserving position and signed scale.
  void setRotation(vm.Quaternion value) {
    _requireTRS();
    setTRS(position: position, rotation: value, scale: _scale!);
  }

  /// Sets signed scale, preserving position and orientation.
  void setScale(double x, double y, double z) {
    _requireTRS();
    setTRS(
      position: position,
      rotation: _rotation!,
      scale: vm.Vector3(x, y, z),
    );
  }

  /// Adds an offset in parent coordinates, unaffected by rotation or scale.
  void translate(double x, double y, double z) {
    checkFiniteComponents([x, y, z], 'offset');
    final p = position;
    setPosition(p.x + x, p.y + y, p.z + z);
  }

  /// Adds an offset in local axes, rotated by R but unaffected by scale.
  void translateLocal(double x, double y, double z) {
    final offset = vm.Vector3(x, y, z);
    checkFiniteComponents(offset.storage, 'offset');
    final delta = _direction(offset);
    translate(delta.x, delta.y, delta.z);
  }

  /// Rotates about a local axis: `R_new = R * R_delta`.
  /// Position and scale are preserved; [angleRadians] follows the right hand rule.
  void rotateLocal(vm.Vector3 axis, double angleRadians) {
    _requireTRS();
    setRotation(_rotation! * _axisRotation(axis, angleRadians));
  }

  /// Rotates about a parent axis: `R_new = R_delta * R`.
  /// Position and scale are preserved; this does not orbit the parent's origin.
  void rotateParent(vm.Vector3 axis, double angleRadians) {
    _requireTRS();
    setRotation(_axisRotation(axis, angleRadians) * _rotation!);
  }

  /// Orients local -Z toward [target], preserving position and signed scale.
  ///
  /// Both [target] and [upHint] are in parent space; the default up hint is +Y.
  /// Coincident target/position, zero up, nonfinite values and nearly parallel
  /// directions (sine of the angle <= 1e-6) throw [ArgumentError] atomically.
  /// Requires [hasTRS]; a matrix with shear is not silently orthogonalized.
  void lookAt(vm.Vector3 target, {vm.Vector3? upHint}) {
    _requireTRS();
    setRotation(lookAtRotation(position, target, upHint: upHint));
  }

  vm.Vector3 _direction(vm.Vector3 local) {
    _requireTRS();
    // Use the same active rotation as Matrix4.compose (Quaternion.rotate uses
    // a different vector convention in vector_math).
    return _rotation!.asRotationMatrix().transformed(local);
  }

  void _requireTRS() {
    if (!hasTRS) {
      throw StateError(
        'Transform has no editable TRS components; use setTRS or setMatrix',
      );
    }
  }

  static vm.Quaternion _axisRotation(vm.Vector3 axis, double angleRadians) {
    checkFiniteComponents([angleRadians], 'angleRadians');
    return vm.Quaternion.axisAngle(unitVector(axis, 'axis'), angleRadians);
  }

  static void _checkAffine(vm.Matrix4 value) {
    checkFiniteComponents(value.storage, 'matrix');
    if (value[3] != 0 || value[7] != 0 || value[11] != 0 || value[15] != 1) {
      throw ArgumentError.value(
        value,
        'matrix',
        'Must be affine with bottom row (0, 0, 0, 1)',
      );
    }
  }

  static (vm.Quaternion, vm.Vector3)? _tryDecompose(vm.Matrix4 value) {
    final columns = List.generate(
      3,
      (i) => vm.Vector3(value[4 * i], value[4 * i + 1], value[4 * i + 2]),
    );
    final lengths = columns.map((column) => column.length).toList();
    if (lengths.any((length) => length == 0 || !length.isFinite)) return null;
    for (var i = 0; i < 3; i++) {
      columns[i].scale(1 / lengths[i]);
    }
    if (columns[0].dot(columns[1]).abs() > _trsTolerance ||
        columns[0].dot(columns[2]).abs() > _trsTolerance ||
        columns[1].dot(columns[2]).abs() > _trsTolerance) {
      return null;
    }
    if (columns[0].dot(columns[1].cross(columns[2])) < 0) {
      columns[0].negate();
      lengths[0] = -lengths[0];
    }
    final rotation = normalizedRotation(
      vm.Quaternion.fromRotation(
        vm.Matrix3.columns(columns[0], columns[1], columns[2]),
      ),
    );
    final scale = vm.Vector3(lengths[0], lengths[1], lengths[2]);
    if (scale.storage.any((value) => !value.isFinite)) return null;
    final reconstructed = vm.Matrix4.compose(
      value.getTranslation(),
      rotation,
      scale,
    );
    for (var column = 0; column < 3; column++) {
      for (var row = 0; row < 3; row++) {
        final i = 4 * column + row;
        if ((reconstructed[i] - value[i]).abs() >
            _trsTolerance * lengths[column].abs()) {
          return null;
        }
      }
    }
    return (rotation, scale);
  }
}
