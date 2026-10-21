part of 'lib.dart';

/// Produces single square: -1 <= x,y  <= 1, z == 0
///
/// This is mostly useful for processing the whole screen
/// in the fragment shader
GeometryBuilder quadGeometry(num size) {
  List<vm.Vector3> vertices = [
    vm.Vector3(-1.0 * size, -1.0 * size, 0.0),
    vm.Vector3(1.0 * size, -1.0 * size, 0.0),
    vm.Vector3(1.0 * size, 1.0 * size, 0.0),
    vm.Vector3(-1.0 * size, 1.0 * size, 0.0),
  ];

  List<vm.Vector2> uvs = [
    vm.Vector2(0.0, 0.0),
    vm.Vector2(1.0, 0.0),
    vm.Vector2(1.0, 1.0),
    vm.Vector2(0.0, 1.0),
  ];

  vm.Vector3 n = vm.Vector3(0.0, 0.0, 1.0);
  List<vm.Vector3> normals = [n, n, n, n];

  GeometryBuilder gb = GeometryBuilder();
  gb.enableAttribute(aTexUV);
  gb.addVerticesFace4(vertices);
  gb.addAttributesVector2(aTexUV, uvs);
  gb.enableAttribute(aNormal);
  gb.addAttributesVector3(aNormal, normals);
  return gb;
}

/// Checkerboard with xstrips X ystrips fields of dim xlen X ylen centered
/// around the origin
GeometryBuilder gridGeometry(
  int xstrips,
  int ystrips,
  double xlen,
  double ylen,
) {
  final double xoffset = xlen * 0.5;
  final double yoffset = ylen * 0.5;
  final double xdelta = xlen / xstrips;
  final double ydelta = xlen / ystrips;

  vm.Vector3 normal = vm.Vector3(0.0, 0.0, 1.0);
  List<vm.Vector3> vertices = List.generate(
    (xstrips + 1) * (ystrips + 1),
    (i) => vm.Vector3.zero(),
  );
  List<vm.Vector3> normals = List.generate(
    (xstrips + 1) * (ystrips + 1),
    (i) => vm.Vector3.zero(),
  );
  List<vm.Vector2> uvs = List.generate(
    (xstrips + 1) * (ystrips + 1),
    (i) => vm.Vector2.zero(),
  );

  int index(int x, int y) {
    return x * (xstrips + 1) + y;
  }

  for (int x = 0; x <= xstrips; ++x) {
    for (int y = 0; y <= ystrips; ++y) {
      final int ii = index(x, y);
      vertices[ii] = vm.Vector3(
        x * xdelta - xoffset,
        y * ydelta - yoffset,
        0.0,
      );
      normals[ii] = normal;
      uvs[ii] = vm.Vector2(x / xstrips, y / ystrips);
    }
  }
  GeometryBuilder gb = GeometryBuilder();
  gb.addVertices(vertices);
  for (int x = 0; x < xstrips; ++x) {
    for (int y = 0; y < ystrips; ++y) {
      gb.addFace4(
        index(x, y),
        index(x + 1, y),
        index(x + 1, y + 1),
        index(x, y + 1),
      );
    }
  }
  gb.enableAttribute(aTexUV);
  gb.addAttributesVector2(aTexUV, uvs);
  gb.enableAttribute(aNormal);
  gb.addAttributesVector3(aNormal, normals);
  return gb;
}
