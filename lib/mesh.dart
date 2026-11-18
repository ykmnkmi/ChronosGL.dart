/// Browser-facing GPU meshes, uploads, and shape factories.
///
/// Each upload/factory returns a caller-owned mesh. CPU geometry stays in
/// `geometry.dart`; dispose a GPU mesh after its last consumer.
library;

export 'src/core/lib.dart'
    show
        GpuMesh,
        MeshData,
        MeshAttributeLayout,
        VertexAttributeLayout,
        uploadGeometry,
        uploadWireframeGeometry,
        geometryBuilderToMeshData,
        geometryBuilderToMeshDataWireframe,
        geometryBuilderToWireframeNormals,
        lineEndPointsToMeshData,
        extractWireframeNormals,
        getMeshFaceArea,
        extractPointCloud;
export 'src/mesh/shape_factories.dart'
    show
        shapeCube,
        shapeWedge,
        shapeCylinder,
        shapeIcosahedron,
        shapeTorusKnot,
        shapeQuad,
        shapeGrid;
