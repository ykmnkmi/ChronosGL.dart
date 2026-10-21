part of 'lib.dart';

final List<vm.Vector3> _cubeNormals = [
  // Front face
  vm.Vector3(0.0, 0.0, 1.0),
  // Back face
  vm.Vector3(0.0, 0.0, -1.0),
  // Top face
  vm.Vector3(0.0, 1.0, 0.0),
  // Bottom face
  vm.Vector3(0.0, -1.0, 0.0),
  // Right face
  vm.Vector3(1.0, 0.0, 0.0),
  // Left face
  vm.Vector3(-1.0, 0.0, 0.0),
];

/// Returns a GeometryBuilder for Cube with TexUVs and optionally
/// Normals.
GeometryBuilder cubeGeometry({
  double x = 1.0,
  double y = 1.0,
  double z = 1.0,
  double uMin = 0.0,
  double uMax = 1.0,
  double vMin = 0.0,
  double vMax = 1.0,
  bool computeNormals = true,
}) {
  List<vm.Vector3> vertices = [
    // Front face
    vm.Vector3(-x, -y, z),
    vm.Vector3(x, -y, z),
    vm.Vector3(x, y, z),
    vm.Vector3(-x, y, z),

    // Back face
    vm.Vector3(-x, -y, -z),
    vm.Vector3(-x, y, -z),
    vm.Vector3(x, y, -z),
    vm.Vector3(x, -y, -z),

    // Top face
    vm.Vector3(-x, y, -z),
    vm.Vector3(-x, y, z),
    vm.Vector3(x, y, z),
    vm.Vector3(x, y, -z),

    // Bottom face
    vm.Vector3(x, -y, z),
    vm.Vector3(-x, -y, z),
    vm.Vector3(-x, -y, -z),
    vm.Vector3(x, -y, -z),

    // Right face
    vm.Vector3(x, -y, -z),
    vm.Vector3(x, y, -z),
    vm.Vector3(x, y, z),
    vm.Vector3(x, -y, z),

    // Left face
    vm.Vector3(-x, -y, -z),
    vm.Vector3(-x, -y, z),
    vm.Vector3(-x, y, z),
    vm.Vector3(-x, y, -z),
  ];

  List<vm.Vector2> uvs = [
    // Front face
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),

    // Back face
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),
    vm.Vector2(uMin, vMin),

    // Top face
    vm.Vector2(uMin, vMax),
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),

    // Bottom face
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),

    // Right face
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),
    vm.Vector2(uMin, vMin),

    // Left face
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),
  ];

  GeometryBuilder gb = GeometryBuilder();
  gb.enableAttribute(aTexUV);
  if (computeNormals) gb.enableAttribute(aNormal);
  gb.addFaces4(6);
  gb.addVertices(vertices);
  gb.addAttributesVector2(aTexUV, uvs);
  if (computeNormals) {
    for (int i = 0; i < _cubeNormals.length; i++) {
      vm.Vector3 n = _cubeNormals[i];
      gb.addAttributesVector3(aNormal, [n, n, n, n]);
    }
  }
  return gb;
}

/*
final List<vm.Vector3> _WedgeNormals = [
  // Front face
  new vm.Vector3(0.0, 0.0, 1.0),
  // Back face
  new vm.Vector3(0.0, 0.0, -1.0),
  // Top/Right face
  new vm.Vector3(1.0, 1.0, 0.0)..normalize(),
  // Bottom face
  new vm.Vector3(0.0, -1.0, 0.0),
  // Left face
  new vm.Vector3(-1.0, 0.0, 0.0)
];
*/

/// A Wedge is the lower part of a cube that was cut in half
/// through the plane: (-x, y, -z) (-x, y, z), (x, -y, -z), (x, -y, z)
GeometryBuilder wedgeGeometry({
  double x = 1.0,
  double y = 1.0,
  double z = 1.0,
  double uMin = 0.0,
  double uMax = 1.0,
  double vMin = 0.0,
  double vMax = 1.0,
  bool computeNormals = true,
}) {
  List<vm.Vector3> vertices3 = [
    // Front face3
    vm.Vector3(-x, -y, z),
    vm.Vector3(x, -y, z),
    vm.Vector3(-x, y, z),

    // Back face3
    vm.Vector3(-x, -y, -z),
    vm.Vector3(-x, y, -z),
    vm.Vector3(x, -y, -z),
  ];

  List<vm.Vector3> vertices4 = [
    // Front face4
    // Top/Right diagonal face
    vm.Vector3(-x, y, -z),
    vm.Vector3(-x, y, z),
    vm.Vector3(x, -y, z),
    vm.Vector3(x, -y, -z),

    // Bottom face
    vm.Vector3(x, -y, z),
    vm.Vector3(-x, -y, z),
    vm.Vector3(-x, -y, -z),
    vm.Vector3(x, -y, -z),

    // Left face
    vm.Vector3(-x, -y, -z),
    vm.Vector3(-x, -y, z),
    vm.Vector3(-x, y, z),
    vm.Vector3(-x, y, -z),
  ];

  List<vm.Vector2> uvs3 = [
    // Front face
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),

    // Back face
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),
  ];

  List<vm.Vector2> uvs4 = [
    // Top/Right diagonal face
    vm.Vector2(uMin, vMax),
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),

    // Bottom face
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),

    // Left face
    vm.Vector2(uMin, vMin),
    vm.Vector2(uMax, vMin),
    vm.Vector2(uMax, vMax),
    vm.Vector2(uMin, vMax),
  ];

  GeometryBuilder gb = GeometryBuilder();
  gb.enableAttribute(aTexUV);
  gb.enableAttribute(aNormal);

  gb.addFaces3(2);
  gb.addVertices(vertices3);
  gb.addAttributesVector2(aTexUV, uvs3);

  gb.addFaces4(3);
  gb.addVertices(vertices4);
  gb.addAttributesVector2(aTexUV, uvs4);

  if (computeNormals) gb.generateNormalsAssumingTriangleMode();
  return gb;
}
