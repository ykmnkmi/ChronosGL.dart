/// Browser-independent skeletons, animations, and pose calculations.
///
/// Key times, sample times, and duration use the same caller-selected clip units.
/// GPU animation textures belong to `render.dart`.
library;

export 'src/animation/lib.dart'
    show
        Bone,
        AnimatedSkeleton,
        recomputeLocalOffsets,
        updateAnimatedSkeleton,
        createAnimationTable,
        BoneAnimation,
        SkeletalAnimation;
