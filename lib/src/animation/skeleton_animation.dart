/*
  This code was heavily inspired by:
  John McCutchan's implementation in the spectre engine.

  Excellent background info:
  Skinned Mesh Animation Using Matrices
  by Bruce J. Veazie |
  https://www.gamedev.net/resources/_/technical/graphics-programming-and-theory/skinned-mesh-animation-using-matrices-r3577

  https://research.ncl.ac.uk/game/mastersdegree/graphicsforgames/skeletalanimation/Tutorial%209%20-%20Skeletal%20Animation.pdf

*/

part of 'lib.dart';

///  the basic unit of a skeleton. Bones form a tree structure and have
///  a parent bone.
class Bone {
  /// Bone indices are topologically ordered; -1 denotes a root parent.
  Bone.named({
    required String name,
    required int index,
    required int parentIndex,
    required vm.Matrix4 localTransform,
    required vm.Matrix4 offsetTransform,
  }) : this(name, index, parentIndex, localTransform, offsetTransform);

  Bone(
    this.boneName,
    this.boneIndex,
    this.parentNum,
    this.localTransform,
    this.offsetTransform,
  ) {
    if (boneIndex < 0 || parentNum < -1 || parentNum >= boneIndex) {
      throw ArgumentError(
        'Bone indices must be nonnegative and follow their parent',
      );
    }
  }

  final String boneName;
  final vm.Matrix4 localTransform;
  final vm.Matrix4 offsetTransform;
  final int boneIndex;
  final int parentNum;

  @override
  String toString() {
    return "BONE[$boneIndex] ($parentNum) $boneName\n"
        "trans:\n$localTransform"
        "offset:\n$offsetTransform";
  }
}

/// represents a Skeleton ready to be used for skinning.
class AnimatedSkeleton {
  AnimatedSkeleton(int length)
    : globalTransforms = List<vm.Matrix4>.unmodifiable(
        List.generate(length, (index) => vm.Matrix4.zero()),
      ),
      skinningTransforms = List<vm.Matrix4>.unmodifiable(
        List.generate(length, (index) => vm.Matrix4.zero()),
      );

  // one for each bone
  final List<vm.Matrix4> globalTransforms;
  final List<vm.Matrix4> skinningTransforms;
}

void recomputeLocalOffsets(List<Bone> skeleton) {
  print("recomputing local transform");
  final List<vm.Matrix4> toRoot = List.generate(
    skeleton.length,
    (i) => vm.Matrix4.zero(),
  );
  for (int i = 0; i < skeleton.length; i++) {
    Bone bone = skeleton[i];
    if (bone.parentNum < 0) {
      toRoot[i] = vm.Matrix4.identity().multiplied(bone.localTransform);
    } else {
      toRoot[i] = toRoot[bone.parentNum].multiplied(bone.localTransform);
    }
    bone.offsetTransform.copyInverse(toRoot[i]);
  }
}

// Note the bones in skeleton must be in topological order
void updateAnimatedSkeleton(
  List<Bone> skeleton,
  vm.Matrix4 globalOffsetTransform,
  SkeletalAnimation animation,
  AnimatedSkeleton posedSkeleton,
  double time,
) {
  vm.Matrix4 tmp = vm.Matrix4.zero();
  for (int i = 0; i < skeleton.length; i++) {
    Bone bone = skeleton[i];
    vm.Matrix4 t = posedSkeleton.globalTransforms[i];
    if (bone.parentNum < 0) {
      t.setIdentity();
    } else {
      t.setFrom(posedSkeleton.globalTransforms[bone.parentNum]);
    }
    BoneAnimation? a = animation.animList[i];
    if (a != null) {
      a.setBoneMatrixAtTick(time, tmp);
      t.multiply(tmp);
    } else {
      t.multiply(bone.localTransform);
    }
  }

  for (int i = 0; i < skeleton.length; i++) {
    final vm.Matrix4 t = posedSkeleton.skinningTransforms[i];
    //  skinningTransform = skeleton.globalOffsetTransform *
    //                          globalTransform * offsetTransform
    // TODO: use "multiply into" if available
    t.setFrom(globalOffsetTransform);
    t.multiply(posedSkeleton.globalTransforms[i]);
    t.multiply(skeleton[i].offsetTransform);
  }
}

// This is meant to be put into a Texture with dimensions
// (skeleton.length * 16) x (time.length)
// If the texture is RGBA this reduces to
// (skeleton.length * 4) x (time.length)
Float32List createAnimationTable(
  List<Bone> skeleton,
  vm.Matrix4 globalOffsetTransform,
  SkeletalAnimation animation,
  List<double> time,
) {
  AnimatedSkeleton posedSkeleton = AnimatedSkeleton(skeleton.length);
  Float32List data = Float32List(skeleton.length * 16 * time.length);
  int pos = 0;
  for (double t in time) {
    updateAnimatedSkeleton(
      skeleton,
      globalOffsetTransform,
      animation,
      posedSkeleton,
      t,
    );
    for (vm.Matrix4 m in posedSkeleton.skinningTransforms) {
      for (int i = 0; i < 16; ++i) {
        data[pos + i] = m[i];
      }
      pos += 16;
    }
  }
  return data;
}

/// represents Key frame animation data for a single bone in a skeleton.
class BoneAnimation {
  /// Times use animation ticks; values are copied and held until the next key.
  BoneAnimation.keyframes({
    required Bone bone,
    List<double> positionTimes = const [],
    List<vm.Vector3> positions = const [],
    List<double> rotationTimes = const [],
    List<vm.Quaternion> rotations = const [],
    List<double> scaleTimes = const [],
    List<vm.Vector3> scales = const [],
  }) : this(
         bone,
         positionTimes,
         positions,
         rotationTimes,
         rotations,
         scaleTimes,
         scales,
       );

  /// Construct bone animation with [boneName]. Animation key frames
  /// will be loaded from [positions], [rotations], and [scales].
  BoneAnimation(
    this.bone,
    this._positionTimes,
    this._positionValues,
    this._rotationTimes,
    this._rotationValues,
    this._scaleTimes,
    this._scaleValues,
  ) {
    if ((_positionTimes.isEmpty && _positionValues.isNotEmpty) ||
        (_rotationTimes.isEmpty && _rotationValues.isNotEmpty) ||
        (_scaleTimes.isEmpty && _scaleValues.isNotEmpty)) {
      throw ArgumentError(
        'Keyframe times and values must have matching lengths',
      );
    }
    if (_positionTimes.isEmpty) {
      _positionTimes = [0.0];
      _positionValues = [vm.Vector3(0.0, 0.0, 0.0)];
    }

    if (_rotationTimes.isEmpty) {
      _rotationTimes = [0.0];
      _rotationValues = [vm.Quaternion(0.0, 0.0, 0.0, 1.0)];
    }

    if (_scaleTimes.isEmpty) {
      _scaleTimes = [0.0];
      _scaleValues = [vm.Vector3(1.0, 1.0, 1.0)];
    }

    _validateTrack(_rotationTimes, _rotationValues.length, 'rotations');
    _validateTrack(_positionTimes, _positionValues.length, 'positions');
    _validateTrack(_scaleTimes, _scaleValues.length, 'scales');
    _positionTimes = List<double>.unmodifiable(_positionTimes);
    _rotationTimes = List<double>.unmodifiable(_rotationTimes);
    _scaleTimes = List<double>.unmodifiable(_scaleTimes);
    _positionValues = [for (final value in _positionValues) value.clone()];
    _rotationValues = [
      for (final value in _rotationValues) vm.Quaternion.copy(value),
    ];
    _scaleValues = [for (final value in _scaleValues) value.clone()];
  }

  final Bone bone;

  List<double> _positionTimes;
  List<vm.Vector3> _positionValues;
  List<double> _rotationTimes;
  List<vm.Quaternion> _rotationValues;
  List<double> _scaleTimes;
  List<vm.Vector3> _scaleValues;

  static void _validateTrack(List<double> times, int values, String name) {
    if (times.length != values || times.isEmpty) {
      throw ArgumentError('$name require matching nonempty times and values');
    }
    for (var i = 0; i < times.length; i++) {
      if (!times[i].isFinite || (i > 0 && times[i] < times[i - 1])) {
        throw ArgumentError('$name times must be finite and ordered');
      }
    }
  }

  static int _findTime(List<double> timeList, double t) {
    for (int i = 0; i < timeList.length - 1; i++) {
      if (t < timeList[i + 1]) {
        return i;
      }
    }
    return 0;
  }

  /// Set [boneMatrix] to correspond to bone animation at time [t].
  /// Does not interpolate between key frames.
  void setBoneMatrixAtTick(double tick, vm.Matrix4 boneMatrix) {
    if (!tick.isFinite) {
      throw ArgumentError.value(tick, 'tick', 'Must be finite');
    }
    final int scaleIndex = _findTime(_scaleTimes, tick);
    assert(scaleIndex >= 0);
    final int positionIndex = _findTime(_positionTimes, tick);
    assert(positionIndex >= 0);
    final int rotationIndex = _findTime(_rotationTimes, tick);
    assert(rotationIndex >= 0);
    vm.Vector3 s = _scaleValues[scaleIndex];
    vm.Vector3 t = _positionValues[positionIndex];
    vm.Quaternion r = _rotationValues[rotationIndex];
    boneMatrix.setFromTranslationRotationScale(t, r, s);
  }

  @override
  String toString() {
    List<String> s = [];
    //s.add("${bone.boneName} [${bone.boneIndex}]");
    s.add(bone.boneName);
    s.add("${_positionTimes.length}: $_positionValues");
    s.add("${_rotationTimes.length}: $_rotationValues");
    s.add("${_scaleTimes.length}: $_scaleValues");
    return s.join("\n");
  }
}

/// represents Key frame animation data for an entire skeleton.
class SkeletalAnimation {
  /// duration uses the same animation ticks as BoneAnimation keyframes.
  SkeletalAnimation.named({
    required String name,
    required double duration,
    required int boneCount,
  }) : this(name, duration, boneCount);

  SkeletalAnimation(this.name, this.duration, int length)
    : _animList = List<BoneAnimation?>.filled(length, null) {
    if (!duration.isFinite || duration < 0) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Must be finite and nonnegative',
      );
    }
  }

  final String name;
  final List<BoneAnimation?> _animList;

  /// Read-only track slots; use insertBone to preserve bone index consistency.
  late final List<BoneAnimation?> animList = UnmodifiableListView(_animList);
  final double duration;

  void insertBone(BoneAnimation ba) {
    final index = ba.bone.boneIndex;
    if (index < 0 || index >= _animList.length) {
      throw ArgumentError('Bone index is outside this animation');
    }
    if (_animList[index] != null) {
      throw StateError('Bone already has an animation');
    }
    _animList[index] = ba;
  }

  @override
  String toString() {
    return "SkeletalAnimation[$name, duration: $duration, frames: ${animList.length}]";
  }
}
