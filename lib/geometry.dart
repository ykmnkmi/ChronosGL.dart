/// Browser-independent CPU geometry, shape factories, and polygon algorithms.
///
/// Validate edited builders before uploading them through `render.dart`.
/// CPU geometry collections are intentionally editable; validation guards upload.
library;

export 'src/core/geometry_builder.dart'
    show GeometryBuilder, Face3, Face4, normalFromPoints;
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
export 'src/shape/lib.dart'
    show
        cubeGeometry,
        wedgeGeometry,
        cylinderGeometry,
        cylinderGeometryWireframeFriendly,
        coneGeometryWireframeFrienly,
        coneGeometryWireframeFriendly,
        icosahedronGeometry,
        quadGeometry,
        gridGeometry,
        torusKnotGetPos,
        torusKnotGeometry,
        torusKnotGeometryWireframeFriendly,
        torusKnotGeometryTriangularWireframeFriendly,
        buildPlaneVectors,
        tubeHullBands,
        ParametricCurveFunc,
        parametricCurvePointsAndTangents;
export 'src/polygon/lib.dart'
    show
        getSignedArea,
        getBounds,
        isInTriangle,
        lineIntersection,
        colinear,
        filterDupsAndColinear,
        isInPolygon,
        isCounterClockWise,
        isConvex,
        getContourGradient,
        contourCircle,
        generalProjection,
        simpleExtrusionAxisZ,
        easingCosine,
        easingSine,
        easingLinear,
        easingQuadratic,
        easingCubic,
        Easing,
        mapStringToEasing,
        bevelSupportPoints,
        bevelStrips,
        triangulate;
