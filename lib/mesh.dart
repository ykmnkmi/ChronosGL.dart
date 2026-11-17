/// Browser-facing GPU mesh factories.
///
/// Every factory uploads a new mesh for the supplied program. The caller owns
/// that mesh and must dispose it after use. Use `geometry.dart` for CPU-only
/// geometry construction without a WebGL context.
library;

export 'src/core/lib.dart'
    show
        GpuMesh,
        MeshData,
        MeshAttributeLayout,
        VertexAttributeLayout,
        uploadGeometry,
        uploadWireframeGeometry;
export 'src/mesh/shape_factories.dart';
