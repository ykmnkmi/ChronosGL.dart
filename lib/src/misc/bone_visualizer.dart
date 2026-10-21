part of 'lib.dart';

List<vm.Vector3> bonePosFromSkeleton(List<Bone> bones) {
  List<vm.Vector3> out = [];

  for (int i = 1; i < bones.length; ++i) {
    final Bone a = bones[i];
    final Bone b = bones[a.parentNum];

    out.add(a.localTransform.getTranslation());
    out.add(b.localTransform.getTranslation());
  }
  print("skeleton bone ${out.length}");
  return out;
}

List<vm.Vector3> bonePosFromAnimatedSkeleton(
  List<Bone> bones,
  AnimatedSkeleton posed, {
  double scale = 1.0,
}) {
  List<vm.Vector3> out = [];

  for (int i = 0; i < bones.length; ++i) {
    final int parent = bones[i].parentNum;
    if (parent == -1) continue;
    out.add(posed.globalTransforms[i].getTranslation() * scale);
    out.add(posed.globalTransforms[parent].getTranslation() * scale);
  }
  //print("skeleton bone ${out.length}");
  return out;
}

class BoneVisualizer {
  BoneVisualizer(RenderProgram prog, Material mat, this._skeleton, this._anim) {
    _animatedSkeleton = AnimatedSkeleton(_skeleton.length);
    updateAnimatedSkeleton(
      _skeleton,
      _globalOffsetTransform,
      _anim,
      _animatedSkeleton,
      0.0,
    );
    _mdWire = lineEndPointsToMeshData(
      "wire",
      prog,
      bonePosFromAnimatedSkeleton(_skeleton, _animatedSkeleton),
    );
    mesh = Node(_mdWire.name, _mdWire, mat);
  }

  final vm.Matrix4 _globalOffsetTransform = vm.Matrix4.identity();
  late MeshData _mdWire;
  final List<Bone> _skeleton;
  final SkeletalAnimation _anim;
  late AnimatedSkeleton _animatedSkeleton;

  late Node mesh;

  void update(double time) {
    updateAnimatedSkeleton(
      _skeleton,
      _globalOffsetTransform,
      _anim,
      _animatedSkeleton,
      time % _anim.duration,
    );
    List<vm.Vector3> bonePos = bonePosFromAnimatedSkeleton(
      _skeleton,
      _animatedSkeleton,
    );
    _mdWire.changeVertexData(flattenVector3List(bonePos));
  }
}
