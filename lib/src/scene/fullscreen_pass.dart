part of 'lib.dart';

/// A reusable clip-space quad with an independent material and explicit lifetime.
///
/// Owns its uploaded mesh. The default material disables depth testing and
/// writes; a supplied [material] is borrowed without modification. Materials
/// contain borrowed uniforms and textures, so disposing a pass never disposes
/// those values. The [program] is borrowed unless [ownsProgram] is true, which
/// also transfers cleanup responsibility if mesh construction fails.
///
/// Set the framebuffer and viewport before [draw], or add [node] to a
/// [RenderBatch] in a [RenderPass]. Finish using that node before disposing this
/// pass. The mesh owned by the pass stays the same even if node links or its
/// borrowed resource references are changed.
class FullscreenPass {
  FullscreenPass(
    this.program, {
    String name = 'fullscreen',
    Material? material,
    this.ownsProgram = false,
  }) : material =
           material ??
           (Material('$name-material')
             ..forceUniform(cDepthTest, false)
             ..forceUniform(cDepthWrite, false)) {
    try {
      _mesh = uploadGeometry('$name-quad', program, quadGeometry(1));
      node = MeshNode(name, _mesh, this.material);
    } catch (_) {
      if (ownsProgram) {
        try {
          program.dispose();
        } catch (_) {
          // Keep the construction failure as the primary error.
        }
      }
      rethrow;
    }
  }

  final RenderProgram program;
  final Material material;
  final bool ownsProgram;
  late final GpuMesh _mesh;
  late final MeshNode node;
  bool _isDisposed = false;

  GpuMesh get meshData => _mesh;
  bool get isDisposed => _isDisposed;

  /// Draws with borrowed uniforms, leaving the caller's list unchanged.
  ///
  /// The pass material is applied last. [StateError] is thrown after disposal.
  void draw([List<UniformGroup> uniforms = const []]) {
    if (_isDisposed) throw StateError('FullscreenPass has been disposed');
    program.draw(_mesh, [...uniforms, material]);
  }

  /// Releases owned resources once, attempting all cleanup on errors.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    Object? firstError;
    StackTrace? firstStack;
    for (final release in [_mesh.dispose, if (ownsProgram) program.dispose]) {
      try {
        release();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }
}

/// Creates an independent unit quad and material, both borrowed by the node.
///
/// The caller owns the mesh and must dispose it after its last consumer.
@Deprecated('Use FullscreenPass and dispose it after use.')
MeshNode unitNode(RenderProgram program) => MeshNode(
  'unit-mesh',
  uploadGeometry('unit-quad', program, quadGeometry(1)),
  Material('unit-material'),
);
