import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../core/pose_math.dart';
import 'projection.dart';

/// Common mathematical camera contract, independent of rendering and input.
///
/// The pose maps camera-local coordinates to world coordinates, with forward
/// along -Z and up along +Y. It contains only translation and rotation; scale,
/// reflection, shear and scene parenting are not part of this contract.
/// Inputs are copied and vector, quaternion and matrix getters return snapshots.
/// Changes take effect immediately without an update call.
/// Position and orientation are the authoritative state. World/view matrices
/// are derived snapshots and are never used as storage for pose edits.
///
/// Each matrix read reflects the current pose/projection, regardless of read
/// order. Returned vectors, quaternions and matrices, including their typed
/// storage, belong to the caller:
/// editing them cannot change the camera, and later camera edits cannot change
/// them. Use setters to edit the camera, or the `copy*MatrixInto` methods to
/// refresh caller-owned matrices. Those methods never retain their destination
/// and leave it unchanged if matrix calculation fails.
abstract class Camera {
  /// Creates a world-space pose, defaulting to the origin and identity rotation.
  Camera({vm.Vector3? position, vm.Quaternion? rotation})
    : _position = vm.Vector3.copy(position ?? vm.Vector3.zero()),
      _rotation = normalizedRotation(rotation ?? vm.Quaternion.identity()) {
    checkFiniteComponents(_position.storage, 'position');
  }

  final vm.Vector3 _position;
  vm.Quaternion _rotation;

  /// Position of the eye in world space, independent of the projection.
  vm.Vector3 get worldPosition => vm.Vector3.copy(_position);

  /// Normalized orientation mapping camera-local axes to world axes.
  vm.Quaternion get worldRotation => vm.Quaternion.copy(_rotation);

  /// Camera-local to world matrix, containing translation and rotation only.
  vm.Matrix4 get worldMatrix =>
      vm.Matrix4.compose(_position, _rotation, vm.Vector3.all(1));

  /// World to view matrix: the inverse of [worldMatrix].
  ///
  /// For the rigid pose `C = T(eye) * R`, this is `R^-1 * T(-eye)`:
  /// a world point becomes `R^-1 * (point - eye)`. The eye maps to the
  /// view-space origin; directions are rotated without translation (w = 0).
  /// The view translation is therefore `-R^-1 * eye`, not the world position.
  /// This calculation uses the current world snapshot, independently of the
  /// projection, and never writes the inverse back into the camera pose.
  ///
  /// Throws [StateError] if the result cannot be represented as finite Float32.
  vm.Matrix4 get viewMatrix {
    final view = vm.Matrix4.inverted(worldMatrix);
    if (view.storage.any((value) => !value.isFinite)) {
      throw StateError('Camera view matrix is not representable as Float32');
    }
    return view;
  }

  /// View to clip matrix, with near/far mapped to NDC depth -1/+1.
  /// Implementations must return an independent snapshot.
  vm.Matrix4 get projectionMatrix;

  /// World to clip matrix: [projectionMatrix] * [viewMatrix].
  ///
  /// Throws [StateError] if the result cannot be represented as finite Float32.
  vm.Matrix4 get viewProjectionMatrix {
    final combined = projectionMatrix..multiply(viewMatrix);
    if (combined.storage.any((value) => !value.isFinite)) {
      throw StateError('Camera view-projection matrix is not finite Float32');
    }
    return combined;
  }

  /// Copies the current camera-local to world matrix into [out].
  /// No reference to [out] or its storage is retained.
  void copyWorldMatrixInto(vm.Matrix4 out) => out.setFrom(worldMatrix);

  /// Copies the current world to view matrix into [out].
  /// If [viewMatrix] throws, [out] remains unchanged.
  void copyViewMatrixInto(vm.Matrix4 out) => out.setFrom(viewMatrix);

  /// Copies the current view to clip matrix into [out].
  /// If [projectionMatrix] throws, [out] remains unchanged.
  void copyProjectionMatrixInto(vm.Matrix4 out) =>
      out.setFrom(projectionMatrix);

  /// Copies the current world to clip matrix into [out].
  /// If [viewProjectionMatrix] throws, [out] remains unchanged.
  void copyViewProjectionMatrixInto(vm.Matrix4 out) =>
      out.setFrom(viewProjectionMatrix);

  /// Sets the eye position in world coordinates, preserving orientation.
  void setPosition(double x, double y, double z) {
    final next = vm.Vector3(x, y, z);
    checkFiniteComponents(next.storage, 'position');
    _position.setFrom(next);
  }

  /// Copies the eye position in world coordinates, preserving orientation.
  void setPositionFromVector(vm.Vector3 value) =>
      setPosition(value.x, value.y, value.z);

  /// Copies and normalizes a nonzero world-space orientation, preserving position.
  void setRotation(vm.Quaternion value) {
    _rotation = normalizedRotation(value);
  }

  /// Points local -Z toward a world-space [target], preserving [worldPosition].
  ///
  /// [upHint] is a world-space direction, defaulting to +Y. Nonfinite values,
  /// a coincident target, zero up or nearly parallel directions (sine <= 1e-6)
  /// throw [ArgumentError] without changing the pose.
  void lookAt(vm.Vector3 target, {vm.Vector3? upHint}) {
    _rotation = normalizedRotation(
      lookAtRotation(_position, target, upHint: upHint),
    );
  }
}

/// A camera with a symmetric perspective projection.
class PerspectiveCamera extends Camera {
  /// [fovYRadians] is the full vertical field of view, defaulting to 50 degrees.
  /// [aspectRatio] is width / height. Clipping distances are in scene units.
  /// Requires finite `0 < fovYRadians < pi`, `aspectRatio > 0`, `0 < near < far`.
  /// Invalid ranges or a nonfinite/singular Float32 matrix throw [ArgumentError].
  /// Infinite far and reversed-Z are unsupported; no canvas resize is implied.
  PerspectiveCamera({
    double fovYRadians = 50 * math.pi / 180,
    double aspectRatio = 1,
    required double near,
    required double far,
    super.position,
    super.rotation,
  }) : _projection = PerspectiveProjection(
         fovYRadians: fovYRadians,
         aspectRatio: aspectRatio,
         near: near,
         far: far,
       );

  /// Shares an immutable projection, with a separate world-space camera pose.
  PerspectiveCamera.fromProjection(
    PerspectiveProjection projection, {
    super.position,
    super.rotation,
  }) : _projection = projection;

  PerspectiveProjection _projection;

  /// The current immutable projection, safe to reuse for another camera/shadow.
  /// [setProjection] replaces it without changing a previously returned value.
  PerspectiveProjection get projection => _projection;

  /// Full vertical field of view in radians.
  double get fovYRadians => _projection.fovYRadians;

  /// Width divided by height; independent of any canvas.
  double get aspectRatio => _projection.aspectRatio;

  /// Positive distance to the near clipping plane at view-space z = -near.
  double get near => _projection.near;

  /// Distance to the far clipping plane at view-space z = -far.
  double get far => _projection.far;

  @override
  vm.Matrix4 get projectionMatrix => _projection.matrix;

  /// Replaces all projection parameters atomically, preserving the camera pose.
  /// All four named parameters are required; use getters for unchanged values.
  ///
  /// Invalid ranges or a nonfinite/singular Float32 matrix throw [ArgumentError]
  /// without changing any parameters. Infinite far and reversed-Z are unsupported.
  void setProjection({
    required double fovYRadians,
    required double aspectRatio,
    required double near,
    required double far,
  }) {
    _projection = PerspectiveProjection(
      fovYRadians: fovYRadians,
      aspectRatio: aspectRatio,
      near: near,
      far: far,
    );
  }
}

/// A camera with explicit orthographic bounds in view-space scene units.
///
/// Bounds do not change automatically with a canvas or aspect ratio. Zero and
/// negative near distances are supported, including volumes used for shadows.
class OrthographicCamera extends Camera {
  /// Requires finite `left < right`, `bottom < top` and `near < far`.
  /// Invalid ranges or a nonfinite/singular Float32 matrix throw [ArgumentError].
  OrthographicCamera({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
    super.position,
    super.rotation,
  }) : _projection = OrthographicProjection(
         left: left,
         right: right,
         bottom: bottom,
         top: top,
         near: near,
         far: far,
       );

  /// Shares immutable bounds, with a separate world-space camera pose.
  OrthographicCamera.fromProjection(
    OrthographicProjection projection, {
    super.position,
    super.rotation,
  }) : _projection = projection;

  OrthographicProjection _projection;

  /// The current immutable projection, safe to reuse for another camera/shadow.
  /// [setProjection] replaces it without changing a previously returned value.
  OrthographicProjection get projection => _projection;

  /// Left clipping boundary in view space.
  double get left => _projection.left;

  /// Right clipping boundary in view space.
  double get right => _projection.right;

  /// Bottom clipping boundary in view space.
  double get bottom => _projection.bottom;

  /// Top clipping boundary in view space.
  double get top => _projection.top;

  /// Signed near distance; the clipping plane is at view-space z = -near.
  double get near => _projection.near;

  /// Signed far distance; the clipping plane is at view-space z = -far.
  double get far => _projection.far;

  @override
  vm.Matrix4 get projectionMatrix => _projection.matrix;

  /// Replaces all bounds atomically, preserving the camera pose.
  /// All six named parameters are required; use getters for unchanged values.
  ///
  /// Invalid ranges or a nonfinite/singular Float32 matrix throw [ArgumentError]
  /// without changing any parameters. No resize policy is applied implicitly.
  void setProjection({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {
    _projection = OrthographicProjection(
      left: left,
      right: right,
      bottom: bottom,
      top: top,
      near: near,
      far: far,
    );
  }
}
