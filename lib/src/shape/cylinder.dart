part of 'lib.dart';

// single color cylinder
// uv mapping is weird to help with debugging

GeometryBuilder cylinderGeometry(
  double radTop,
  double radBot,
  double height,
  int radialSubdivisions,
  bool computeNormals,
) {
  assert(radialSubdivisions > 2, "must have at least 3 divisions");
  double halfHeight = height / 2;

  List<vm.Vector3> vertices = [];
  List<vm.Vector2> uvs = [];
  List<vm.Vector3> normal = [];
  // top center
  vertices.add(vm.Vector3(0.0, halfHeight, 0.0));
  uvs.add(vm.Vector2(0.0, 0.0));
  if (computeNormals) normal.add(vm.Vector3(0.0, 1.0, 0.0));
  // bottom center
  vertices.add(vm.Vector3(0.0, -halfHeight, 0.0));
  uvs.add(vm.Vector2(1.0, 1.0));
  if (computeNormals) normal.add(vm.Vector3(0.0, -1.0, 0.0));

  // First round for disks
  for (int i = 0; i < radialSubdivisions; i++) {
    double u = i / radialSubdivisions;

    double x = math.sin(u * math.pi * 2);
    double z = math.cos(u * math.pi * 2);

    vertices.add(vm.Vector3(x * radTop, halfHeight, z * radTop));
    uvs.add(vm.Vector2(u, 1.0));
    if (computeNormals) normal.add(vm.Vector3(0.0, 1.0, 0.0));
    vertices.add(vm.Vector3(x * radBot, -halfHeight, z * radBot));
    uvs.add(vm.Vector2(u, 0.0));
    if (computeNormals) normal.add(vm.Vector3(0.0, -1.0, 0.0));
  }

  if (computeNormals) {
    assert(vertices.length == 2 + 2 * radialSubdivisions);
    assert(uvs.length == 2 + 2 * radialSubdivisions);
    // Second set of vertices for walls with different normals
    for (int i = 0; i < 2 * radialSubdivisions; i += 2) {
      vertices.add(vertices[i + 2]);
      vertices.add(vertices[i + 3]);
      uvs.add(uvs[i + 2]);
      uvs.add(uvs[i + 3]);
      // Now compute normals
      vm.Vector3 a = vertices[i + 2];
      vm.Vector3 b = vertices[i + 3];
      // note: we added vertices so we will not access out  of bounds
      vm.Vector3 c = vertices[i + 4];
      vm.Vector3 temp = vm.Vector3.zero();
      vm.Vector3 norm = vm.Vector3.zero();
      normalFromPoints(a, b, c, temp, norm);
      normal.add(norm);
      normal.add(norm);
    }
    assert(vertices.length == 2 + 4 * radialSubdivisions);
  } else {
    assert(vertices.length == 2 + 2 * radialSubdivisions);
  }
  GeometryBuilder gb = GeometryBuilder();
  gb.enableAttribute(aTexUV);
  gb.addVertices(vertices);
  gb.addAttributesVector2(aTexUV, uvs);
  if (computeNormals) {
    gb.enableAttribute(aNormal);
    gb.addAttributesVector3(aNormal, normal);
  }
  // triangles for top and bottom
  for (int i = 0; i < radialSubdivisions; i++) {
    final int t = (i * 2) + 2; // top node
    final int b = t + 1; // bot node
    int j = i + 1;
    if (j == radialSubdivisions) j = 0;
    final int tnext = (j * 2) + 2;
    final int bnext = tnext + 1;
    // triangle in top circle
    gb.addFace3(0, t, tnext);
    // triangle in bottom circle
    gb.addFace3(1, bnext, b);

    // Wall
    int o = computeNormals ? radialSubdivisions * 2 : 0;
    gb.addFace4(o + tnext, o + t, o + b, o + bnext);
  }
  return gb;
}

/// Like CylinderGeometry but with duplicate Vertices to make it possible
///  to add aCenter attributes with generateWireframeCenters()
GeometryBuilder cylinderGeometryWireframeFriendly(
  double radTop,
  double radBot,
  double height,
  int radialSubdivisions,
) {
  // Compute points on edges
  final double halfHeight = height / 2;
  List<vm.Vector3> top = [];
  List<vm.Vector3> bot = [];
  for (int i = 0; i < radialSubdivisions; i++) {
    double u = i / radialSubdivisions * math.pi * 2.0;
    double x = math.sin(u);
    double z = math.cos(u);
    top.add(vm.Vector3(radTop * x, halfHeight, radTop * z));
    bot.add(vm.Vector3(radBot * x, -halfHeight, radBot * z));
  }
  // repeat three first point so we can safely index with +1
  top.add(top[0]);
  bot.add(bot[0]);
  assert(top.length == radialSubdivisions + 1);
  assert(bot.length == radialSubdivisions + 1);

  final vm.Vector2 zero = vm.Vector2(0.0, 0.0);
  final vm.Vector3 centerTop = vm.Vector3(0.0, halfHeight, 0.0);
  final vm.Vector3 centerBot = vm.Vector3(0.0, -halfHeight, 0.0);

  GeometryBuilder gb = GeometryBuilder();
  gb.enableAttribute(aTexUV);

  // Q: Why do we have to repeat the vertices?
  // A: Without it example wireframe does not work
  // top and bottom are Face3
  gb.addFaces3(2 * radialSubdivisions);
  for (int i = 0; i < radialSubdivisions; i++) {
    gb.addVertices([centerTop, top[i], top[i + 1]]);
    gb.addVertices([centerBot, bot[i + 1], bot[i]]);
    // TODO: fix these:
    gb.addAttributesVector2(aTexUV, [zero, zero, zero]);
    gb.addAttributesVector2(aTexUV, [zero, zero, zero]);
  }

  gb.addFaces4(radialSubdivisions);
  for (int i = 0; i < radialSubdivisions; i++) {
    gb.addVertices([top[i + 1], top[i], bot[i], bot[i + 1]]);
    // TODO: fix these:
    gb.addAttributesVector2(aTexUV, [zero, zero, zero, zero]);
  }
  return gb;
}

/// Like ConeGeometry but with duplicate Vertices to make it possible
///  to add aCenter attributes with generateWireframeCenters()
GeometryBuilder coneGeometryWireframeFrienly(
  double rad,
  double height,
  int radialSubdivisions,
) {
  // Compute points on edges
  final double halfHeight = height / 2;
  vm.Vector3 top = vm.Vector3(0.0, halfHeight, 0.0);

  List<vm.Vector3> bot = [];
  for (int i = 0; i < radialSubdivisions; i++) {
    double u = i / radialSubdivisions * math.pi * 2.0;
    double x = math.sin(u);
    double z = math.cos(u);
    bot.add(vm.Vector3(rad * x, -halfHeight, rad * z));
  }
  // repeat three first point so we can safely index with +1
  bot.add(bot[0]);
  assert(bot.length == radialSubdivisions + 1);

  final vm.Vector2 zero = vm.Vector2(0.0, 0.0);
  final vm.Vector3 centerBot = vm.Vector3(0.0, -halfHeight, 0.0);

  GeometryBuilder gb = GeometryBuilder();
  gb.enableAttribute(aTexUV);

  // Q: Why do we have to repeat the vertices?
  // A: Without it example wireframe does not work
  // top and bottom are Face3
  gb.addFaces3(radialSubdivisions);
  for (int i = 0; i < radialSubdivisions; i++) {
    gb.addVertices([centerBot, bot[i + 1], bot[i]]);
    // TODO: fix these:
    gb.addAttributesVector2(aTexUV, [zero, zero, zero]);
  }

  gb.addFaces3(radialSubdivisions);
  for (int i = 0; i < radialSubdivisions; i++) {
    gb.addVertices([top, bot[i], bot[i + 1]]);
    // TODO: fix these:
    gb.addAttributesVector2(aTexUV, [zero, zero, zero]);
  }
  return gb;
}
