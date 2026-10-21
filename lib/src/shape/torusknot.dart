part of 'lib.dart';

/// Parametric representation of a TorusKnot
/// u varies from 0 - 2 PI
/// q == 0 and p == 1 results in a torus
void torusKnotGetPos(
  double u,
  int q,
  int p,
  double radius,
  double heightScale,
  vm.Vector3 vec,
) {
  final double cq = math.cos(q * u);
  final double sq = math.sin(q * u);
  final double cp = math.cos(p * u);
  final double sp = math.sin(p * u);

  vec.x = radius * (2.0 + cq) * 0.5 * cp;
  vec.y = radius * (2.0 + cq) * 0.5 * sp;
  vec.z = heightScale * radius * 0.5 * sq;
}

/// q == 0 and p == 1 results in a torus
GeometryBuilder torusKnotGeometry({
  double radius = 20.0,
  double tubeRadius = 4.0,
  int segmentsR = 128,
  int segmentsT = 16,
  int p = 2,
  int q = 3,
  double heightScale = 1.0,
  // wrap false => start and end node are separate vertices
  bool wrap = false,
  bool computeUVs = true,
  bool computeNormals = true,
  bool inside = false,
}) {
  void curveFunc(double u, vm.Vector3 out) {
    torusKnotGetPos(u, q, p, radius, heightScale, out);
  }

  final List<vm.Vector3> pointsAndTangents = parametricCurvePointsAndTangents(
    curveFunc,
    0.0,
    2.0 * math.pi,
    segmentsR,
    halfOpen: true,
  );
  if (!wrap) {
    pointsAndTangents.add(pointsAndTangents[0]);
    pointsAndTangents.add(pointsAndTangents[1]);
  }
  final int h = segmentsR + (wrap ? 0 : 1);
  assert(pointsAndTangents.length == 2 * h);

  final List<List<vm.Vector3>> bands = tubeHullBands(
    pointsAndTangents,
    segmentsT,
    tubeRadius,
  );
  if (!wrap) {
    for (List<vm.Vector3> b in bands) {
      b.add(b[0]);
      b.add(b[1]);
    }
  }
  assert(bands.length == h);
  final int w = segmentsT + (wrap ? 0 : 1);

  assert(bands[0].length == 2 * w);

  final GeometryBuilder gb = GeometryBuilder();

  for (List<vm.Vector3> lst in bands) {
    for (int i = 0; i < lst.length; i += 2) {
      gb.addVertexTakeOwnership(lst[i]);
    }
  }
  assert(gb.vertices.length == w * h);

  gb.generateRegularGridFaces(w, h, wrap, inside);

  if (computeUVs) {
    assert(!wrap, "uvs do not work well with wrapping");
    gb.generateRegularGridUV(w, h);
    assert(gb.attributes[aTexUV]?.length == gb.vertices.length);
  }

  if (computeNormals) {
    gb.enableAttribute(aNormal);
    for (List<vm.Vector3> lst in bands) {
      for (int i = 0; i < lst.length; i += 2) {
        gb.addAttributeVector3(aNormal, lst[i + 1]);
      }
    }
    assert(gb.attributes[aNormal]?.length == gb.vertices.length);
  }
  return gb;
}

/// Like TorusKnotGeometry but with duplicate Vertices to make it
/// possible to add aCenter attributes with generateWireframeCenters()
GeometryBuilder torusKnotGeometryWireframeFriendly({
  double radius = 20.0,
  double tubeRadius = 4.0,
  int segmentsR = 128,
  int segmentsT = 16,
  int p = 2,
  int q = 3,
  double heightScale = 1.0,
  bool computeUVs = true,
  bool computeNormals = true,
  bool inside = false,
}) {
  void curveFunc(double u, vm.Vector3 out) {
    torusKnotGetPos(u, q, p, radius, heightScale, out);
  }

  final List<vm.Vector3> pointsAndTangents = parametricCurvePointsAndTangents(
    curveFunc,
    0.0,
    2.0 * math.pi,
    segmentsR,
    halfOpen: true,
  );
  pointsAndTangents.add(pointsAndTangents[0]);
  pointsAndTangents.add(pointsAndTangents[1]);
  final int h = segmentsR + 1;
  assert(pointsAndTangents.length == 2 * h);
  final List<List<vm.Vector3>> bands = tubeHullBands(
    pointsAndTangents,
    segmentsT,
    tubeRadius,
  );
  for (List<vm.Vector3> b in bands) {
    b.add(b[0]);
    b.add(b[1]);
  }
  assert(bands.length == h);

  final GeometryBuilder gb = GeometryBuilder();

  for (int i = 0; i < segmentsR; ++i) {
    for (int j = 0; j < segmentsT; ++j) {
      final int ip = i + 1;
      final int jp = j + 1;
      gb.addFaces4(1, inside);
      gb.addVerticesTakeOwnership([
        bands[i][jp * 2],
        bands[ip][jp * 2],
        bands[ip][j * 2],
        bands[i][j * 2],
      ]);
    }
  }

  if (computeUVs) {
    gb.enableAttribute(aTexUV);
    for (int i = segmentsR - 1; i >= 0; --i) {
      for (int j = 0; j < segmentsT; ++j) {
        final int ip = i + 1;
        final int jp = j + 1;
        gb.addAttributesVector2TakeOwnership(aTexUV, [
          vm.Vector2(i / segmentsR, jp / segmentsT),
          vm.Vector2(ip / segmentsR, jp / segmentsT),
          vm.Vector2(ip / segmentsR, j / segmentsT),
          vm.Vector2(i / segmentsR, j / segmentsT),
        ]);
      }
    }
  }

  if (computeNormals) gb.generateNormalsAssumingTriangleMode();
  return gb;
}

/// Like TorusKnotGeometryWireframeFriendly  but with triangles rather
/// than quads.
GeometryBuilder torusKnotGeometryTriangularWireframeFriendly({
  double radius = 20.0,
  double tubeRadius = 4.0,
  int segmentsR = 128,
  int segmentsT = 16,
  int p = 2,
  int q = 3,
  double heightScale = 1.0,
  bool inside = false,
}) {
  void curveFunc(double u, vm.Vector3 out) {
    torusKnotGetPos(u, q, p, radius, heightScale, out);
  }

  final List<vm.Vector3> pointsAndTangents = parametricCurvePointsAndTangents(
    curveFunc,
    0.0,
    2.0 * math.pi,
    segmentsR,
    halfOpen: true,
  );
  pointsAndTangents.add(pointsAndTangents[0]);
  pointsAndTangents.add(pointsAndTangents[1]);
  final int h = segmentsR + 1;
  assert(pointsAndTangents.length == 2 * h);
  final List<List<vm.Vector3>> bands = tubeHullBands(
    pointsAndTangents,
    segmentsT,
    tubeRadius,
  );
  for (List<vm.Vector3> b in bands) {
    b.add(b[0]);
    b.add(b[1]);
  }
  assert(bands.length == h);

  final GeometryBuilder gb = GeometryBuilder();

  for (int i = 0; i < segmentsR; ++i) {
    for (int j = 0; j < segmentsT; j += 2) {
      final int jp = j + (i % 2) * 3;
      gb.addFaces3(2, inside);
      vm.Vector3 b(int x, int y) => bands[x % segmentsR][(y % segmentsT) * 2];

      gb.addVerticesTakeOwnership([b(i, jp + 2), b(i + 1, jp + 1), b(i, jp)]);

      gb.addVerticesTakeOwnership([
        b(i + 1, jp + 3),
        b(i + 1, jp + 1),
        b(i, jp + 2),
      ]);
    }
  }

  return gb;
}
