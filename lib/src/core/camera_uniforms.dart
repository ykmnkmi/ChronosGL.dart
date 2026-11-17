part of 'lib.dart';

/// Adapts a mathematical [Camera] to [RenderProgram.draw] and scene uniforms.
///
/// Each [getUniforms] call returns a fresh map containing independent snapshots:
/// [uPerspectiveViewMatrix] is projection * view for either projection type,
/// and [uEyePosition] is the eye in world space. Camera edits take effect on
/// the next read/draw without an update call. No model transform is included.
///
/// The two camera uniforms always come from [camera], overriding values supplied
/// through inherited setters. Additional uniforms keep [UniformGroup] semantics.
/// This rendering adapter is exported by `chronosgl.dart`, not `camera.dart`.
class CameraUniforms extends UniformGroup {
  CameraUniforms(this.camera, [String name = 'camera']) : super(name);

  /// Borrowed camera; the adapter does not modify its pose or projection.
  final Camera camera;

  @override
  bool hasUniform(String canonical) =>
      canonical == uPerspectiveViewMatrix ||
      canonical == uEyePosition ||
      super.hasUniform(canonical);

  /// Returns caller-owned camera values, never reusable internal scratch.
  /// If camera matrix calculation fails, its error propagates without caching
  /// a partial result or changing any previously returned snapshot.
  @override
  Map<String, Object> getUniforms() => {
    ...super.getUniforms(),
    uPerspectiveViewMatrix: camera.viewProjectionMatrix,
    uEyePosition: camera.worldPosition,
  };
}
