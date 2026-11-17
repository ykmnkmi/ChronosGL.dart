/// Browser-independent CPU geometry builders, shapes, and polygon algorithms.
///
/// Create and validate geometry on the Dart VM. Use `chronosgl.dart` and
/// `uploadGeometry` to create GPU buffers when a WebGL context is available.
library;

export 'src/core/geometry_builder.dart';
export 'src/core/shader_object.dart'
    show
        ShaderVarDesc,
        introduceNewShaderVar,
        retrieveShaderVarDesc,
        varTypeFloat,
        varTypeVec2,
        varTypeVec3,
        varTypeVec4,
        varTypeUvec4,
        aPosition,
        aColor,
        aColorAlpha,
        aTexUV,
        aNormal,
        aBinormal,
        aTangent,
        aBitangent,
        aCenter,
        aPointSize,
        aBoneIndex,
        aBoneWeight;
export 'src/shape/lib.dart';
export 'src/polygon/lib.dart';
