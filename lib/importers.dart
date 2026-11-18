/// Browser-independent parsers for Wavefront, ThreeJS JSON, and Assimp JSON.
///
/// These functions consume already loaded data; use `web.dart` for URL loading.
library;

export 'src/importer/lib.dart'
    show
        importGeometryFromAssimp2JsonMesh,
        importSkeletonFromAssimp2Json,
        importAnimationFromAssimp2Json,
        importGeometryFromThreeJsJson,
        importAnimationFromThreeJsJson,
        importSkeletonFromThreeJsJson,
        convertToVector3List,
        convertToVector2List,
        convertToVector4List,
        makeVector3,
        makeTransVector3,
        makeScaleVector3,
        makeQuaternion,
        importGeometryFromWavefront;
