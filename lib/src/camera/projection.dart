import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

/// A view-to-clip projection, independent of camera pose, uniforms and browsers.
///
/// Implementations must be immutable and return independent matrix snapshots.
/// Matrices use column vectors and OpenGL NDC depth: -near maps to -1 and
/// -far maps to +1. For a camera or shadow, compose `matrix * viewMatrix`.
abstract class Projection {
  /// Creates a projection without rendering resources or subscriptions.
  const Projection();

  /// View-to-clip matrix, returned as an independent snapshot.
  /// Neither the matrix nor its typed storage may alias internal state.
  vm.Matrix4 get matrix;

  /// Copies the view-to-clip matrix into caller-owned storage.
  /// The destination is not retained. If calculation fails, it is unchanged.
  void copyMatrixInto(vm.Matrix4 out) => out.setFrom(matrix);
}

/// An immutable symmetric perspective projection for cameras and spot shadows.
final class PerspectiveProjection extends Projection {
  /// [fovYRadians] is the full vertical field of view, defaulting to 50 degrees.
  /// [aspectRatio] is width / height; clipping distances are in scene units.
  /// Requires finite `0 < fovYRadians < pi`, `aspectRatio > 0`, `0 < near < far`.
  ///
  /// Invalid ranges or a nonfinite/singular Float32 matrix throw [ArgumentError].
  /// Infinite far and reversed-Z are unsupported.
  PerspectiveProjection({
    this.fovYRadians = 50 * math.pi / 180,
    this.aspectRatio = 1,
    required this.near,
    required this.far,
  }) {
    _requireFinite(fovYRadians, 'fovYRadians');
    _requireFinite(aspectRatio, 'aspectRatio');
    _requireFinite(near, 'near');
    _requireFinite(far, 'far');
    if (fovYRadians <= 0 || fovYRadians >= math.pi) {
      throw ArgumentError.value(
        fovYRadians,
        'fovYRadians',
        'Must be in (0, pi)',
      );
    }
    if (aspectRatio <= 0) {
      throw ArgumentError.value(aspectRatio, 'aspectRatio', 'Must be positive');
    }
    if (near <= 0 || far <= near) {
      throw ArgumentError(
        'Perspective clipping distances require 0 < near < far',
      );
    }
    final next = vm.makePerspectiveMatrix(fovYRadians, aspectRatio, near, far);
    _requireProjection(next, [0, 5, 14]);
    _matrix = next;
  }

  /// Full vertical field of view in radians.
  final double fovYRadians;

  /// Width divided by height; independent of any canvas or shadow texture.
  final double aspectRatio;

  /// Positive distance to the near clipping plane at view-space z = -near.
  final double near;

  /// Distance to the far clipping plane at view-space z = -far.
  final double far;

  late final vm.Matrix4 _matrix;

  @override
  vm.Matrix4 get matrix => vm.Matrix4.copy(_matrix);

  @override
  void copyMatrixInto(vm.Matrix4 out) => out.setFrom(_matrix);
}

/// Immutable orthographic bounds for cameras and directional-light shadows.
///
/// Bounds are explicit view-space scene units, independent of canvas size.
/// Zero and negative near distances are supported, including shadow volumes
/// spanning both sides of the light's origin.
final class OrthographicProjection extends Projection {
  /// Requires finite `left < right`, `bottom < top` and `near < far`.
  /// Invalid ranges or a nonfinite/singular Float32 matrix throw [ArgumentError].
  OrthographicProjection({
    required this.left,
    required this.right,
    required this.bottom,
    required this.top,
    required this.near,
    required this.far,
  }) {
    _requireFinite(left, 'left');
    _requireFinite(right, 'right');
    _requireFinite(bottom, 'bottom');
    _requireFinite(top, 'top');
    _requireFinite(near, 'near');
    _requireFinite(far, 'far');
    if (left >= right || bottom >= top || near >= far) {
      throw ArgumentError(
        'Orthographic bounds require left < right, bottom < top, near < far',
      );
    }
    final next = vm.makeOrthographicMatrix(left, right, bottom, top, near, far);
    _requireProjection(next, [0, 5, 10]);
    _matrix = next;
  }

  /// Left clipping boundary in view space.
  final double left;

  /// Right clipping boundary in view space.
  final double right;

  /// Bottom clipping boundary in view space.
  final double bottom;

  /// Top clipping boundary in view space.
  final double top;

  /// Signed near distance; the clipping plane is at view-space z = -near.
  final double near;

  /// Signed far distance; the clipping plane is at view-space z = -far.
  final double far;

  late final vm.Matrix4 _matrix;

  @override
  vm.Matrix4 get matrix => vm.Matrix4.copy(_matrix);

  @override
  void copyMatrixInto(vm.Matrix4 out) => out.setFrom(_matrix);
}

void _requireFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Must be finite');
  }
}

void _requireProjection(vm.Matrix4 matrix, List<int> nonzeroEntries) {
  if (matrix.storage.any((value) => !value.isFinite) ||
      nonzeroEntries.any((index) => matrix[index] == 0)) {
    throw ArgumentError('Projection must be finite and nonsingular in Float32');
  }
}
