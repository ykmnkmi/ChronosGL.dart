import 'package:vector_math/vector_math.dart' as vm;

import '../animation/lib.dart';
import '../core/lib.dart';
import '../scene/lib.dart';

List<vm.Vector3> bonePosFromSkeleton(List<Bone> bones) {
  final points = <vm.Vector3>[];
  for (final bone in bones) {
    if (bone.parentNum < 0) continue;
    points.add(bone.localTransform.getTranslation());
    points.add(bones[bone.parentNum].localTransform.getTranslation());
  }
  return points;
}

List<vm.Vector3> bonePosFromAnimatedSkeleton(
  List<Bone> bones,
  AnimatedSkeleton posed, {
  double scale = 1.0,
}) {
  final points = <vm.Vector3>[];
  for (var i = 0; i < bones.length; i++) {
    final parent = bones[i].parentNum;
    if (parent < 0) continue;
    points.add(posed.globalTransforms[i].getTranslation() * scale);
    points.add(posed.globalTransforms[parent].getTranslation() * scale);
  }
  return points;
}

/// A lazily created animated skeleton wireframe with an owned GPU mesh.
///
/// The skeleton list is copied; bones, animation, material, and program are
/// borrowed. Construction and [update] before [mesh] access allocate no GPU
/// resources. Dispose the visualizer after removing its node from all scenes.
class BoneVisualizer {
  BoneVisualizer(this.program, this.material, List<Bone> skeleton, this._anim)
    : _skeleton = List<Bone>.of(skeleton),
      _animatedSkeleton = AnimatedSkeleton(skeleton.length);

  final RenderProgram program;
  final Material material;
  final vm.Matrix4 _globalOffsetTransform = vm.Matrix4.identity();
  final List<Bone> _skeleton;
  final SkeletalAnimation _anim;
  final AnimatedSkeleton _animatedSkeleton;
  MeshNode? _mesh;
  GpuMesh? _ownedMesh;
  double _time = 0.0;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  bool get isInitialized => _mesh != null;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('BoneVisualizer has been disposed');
  }

  List<vm.Vector3> _points() {
    updateAnimatedSkeleton(
      _skeleton,
      _globalOffsetTransform,
      _anim,
      _animatedSkeleton,
      _anim.duration > 0 ? _time % _anim.duration : 0.0,
    );
    return bonePosFromAnimatedSkeleton(_skeleton, _animatedSkeleton);
  }

  MeshNode get mesh {
    _checkNotDisposed();
    final existing = _mesh;
    if (existing != null) return existing;
    final points = _points();
    final md = program.makeMeshData('bone wireframe', glLines);
    try {
      md.addVertices(flattenVector3List(points));
      md.addFaces(List.generate(points.length, (index) => index));
      _ownedMesh = md;
      return _mesh = MeshNode(md.name, md, material);
    } catch (_) {
      try {
        md.dispose();
      } catch (_) {
        // Preserve the initialization failure.
      }
      rethrow;
    }
  }

  /// Applies animation time in the same units as the supplied animation.
  void update(double time) {
    _checkNotDisposed();
    if (!time.isFinite) {
      throw ArgumentError.value(time, 'time', 'Must be finite');
    }
    _time = time;
    final md = _ownedMesh;
    if (md != null) {
      md.changeVertexData(flattenVector3List(_points()));
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _ownedMesh?.dispose();
  }
}
