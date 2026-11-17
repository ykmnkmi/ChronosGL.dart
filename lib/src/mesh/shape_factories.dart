/// GPU wrappers for the browser-independent shape generators.
library;

import '../core/lib.dart';
import '../shape/lib.dart';

/// Uploads a cube centered at the origin, with half extents [x], [y] and [z].
///
/// UV bounds and [computeNormals] are forwarded to [cubeGeometry]. The caller
/// owns the returned mesh; [prog] is borrowed.
GpuMesh shapeCube(
  RenderProgram prog, {
  double x = 1.0,
  double y = 1.0,
  double z = 1.0,
  double uMin = 0.0,
  double uMax = 1.0,
  double vMin = 0.0,
  double vMax = 1.0,
  bool computeNormals = true,
}) => uploadGeometry(
  'cube',
  prog,
  cubeGeometry(
    x: x,
    y: y,
    z: z,
    uMin: uMin,
    uMax: uMax,
    vMin: vMin,
    vMax: vMax,
    computeNormals: computeNormals,
  ),
);

/// Uploads the lower half of a cube cut through its XY diagonal.
///
/// [x], [y] and [z] are half extents in world units. UV bounds and
/// [computeNormals] have the same meaning as in [wedgeGeometry]. The caller
/// owns the returned mesh; [prog] is borrowed.
GpuMesh shapeWedge(
  RenderProgram prog, {
  double x = 1.0,
  double y = 1.0,
  double z = 1.0,
  double uMin = 0.0,
  double uMax = 1.0,
  double vMin = 0.0,
  double vMax = 1.0,
  bool computeNormals = true,
}) => uploadGeometry(
  'wedge',
  prog,
  wedgeGeometry(
    x: x,
    y: y,
    z: z,
    uMin: uMin,
    uMax: uMax,
    vMin: vMin,
    vMax: vMax,
    computeNormals: computeNormals,
  ),
);

/// Uploads a cylinder along Y, centered at the origin.
///
/// [radTop], [radBot] and the full [height] use world units.
/// [radialSubdivisions] must be at least three. Positional parameters preserve
/// the [cylinderGeometry] contract and existing calls. The caller owns the
/// returned mesh; [prog] is borrowed.
GpuMesh shapeCylinder(
  RenderProgram prog,
  double radTop,
  double radBot,
  double height,
  int radialSubdivisions, [
  bool computeNormals = true,
]) => uploadGeometry(
  'cylinder-$radialSubdivisions',
  prog,
  cylinderGeometry(radTop, radBot, height, radialSubdivisions, computeNormals),
);

/// Uploads an icosahedron sphere with radius [scale] in world units.
///
/// [subdivisions] and [computeNormals] are forwarded to [icosahedronGeometry].
/// The caller owns the returned mesh; [prog] is borrowed.
GpuMesh shapeIcosahedron(
  RenderProgram prog, {
  int subdivisions = 4,
  double scale = 1.0,
  bool computeNormals = true,
}) => uploadGeometry(
  'icosahedron-$subdivisions',
  prog,
  icosahedronGeometry(
    subdivisions: subdivisions,
    scale: scale,
    computeNormals: computeNormals,
  ),
);

/// Uploads a torus knot using the [torusKnotGeometry] parameter contract.
///
/// [radius] and [tubeRadius] use world units; [heightScale] is dimensionless.
/// [segmentsR] and [segmentsT] control the curve and tube subdivisions.
/// [wrap] joins seam vertices and requires [computeUVs] to be false. [inside]
/// reverses the faces. The caller owns the returned mesh; [prog] is borrowed.
GpuMesh shapeTorusKnot(
  RenderProgram prog, {
  double radius = 20.0,
  double tubeRadius = 4.0,
  int segmentsR = 128,
  int segmentsT = 16,
  int p = 2,
  int q = 3,
  double heightScale = 1.0,
  bool wrap = false,
  bool computeUVs = true,
  bool computeNormals = true,
  bool inside = false,
}) => uploadGeometry(
  'torusknot',
  prog,
  torusKnotGeometry(
    radius: radius,
    tubeRadius: tubeRadius,
    segmentsR: segmentsR,
    segmentsT: segmentsT,
    p: p,
    q: q,
    heightScale: heightScale,
    wrap: wrap,
    computeUVs: computeUVs,
    computeNormals: computeNormals,
    inside: inside,
  ),
);

/// Uploads a square in the XY plane with half extent [size] in world units.
///
/// UVs cover [0, 1] and normals face +Z. A size of 1 covers clip space for a
/// fullscreen shader. The caller owns the returned mesh; [prog] is borrowed.
GpuMesh shapeQuad(RenderProgram prog, num size) =>
    uploadGeometry('quad', prog, quadGeometry(size));

/// Uploads an XY grid centered at the origin and facing +Z.
///
/// [xstrips] and [ystrips] count cells; [xlen] and [ylen] are the full lengths
/// in world units. UVs cover [0, 1]. The caller owns the returned mesh;
/// [prog] is borrowed.
GpuMesh shapeGrid(
  RenderProgram prog,
  int xstrips,
  int ystrips,
  double xlen,
  double ylen,
) => uploadGeometry('strips', prog, gridGeometry(xstrips, ystrips, xlen, ylen));
