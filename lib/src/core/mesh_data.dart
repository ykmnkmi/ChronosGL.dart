part of 'lib.dart';

Float32List flattenVector3List(List<vm.Vector3> v, [Float32List? data]) {
  data ??= Float32List(v.length * 3);
  for (int i = 0; i < v.length; ++i) {
    data[i * 3 + 0] = v[i].x;
    data[i * 3 + 1] = v[i].y;
    data[i * 3 + 2] = v[i].z;
  }
  return data;
}

Float32List flattenVector2List(List<vm.Vector2> v, [Float32List? data]) {
  data ??= Float32List(v.length * 2);
  for (int i = 0; i < v.length; ++i) {
    data[i * 2 + 0] = v[i].x;
    data[i * 2 + 1] = v[i].y;
  }
  return data;
}

Float32List flattenVector4List(List<vm.Vector4> v, [Float32List? data]) {
  data ??= Float32List(v.length * 4);
  for (int i = 0; i < v.length; ++i) {
    data[i * 4 + 0] = v[i].x;
    data[i * 4 + 1] = v[i].y;
    data[i * 4 + 2] = v[i].z;
    data[i * 4 + 3] = v[i].w;
  }
  return data;
}

Uint32List flattenUvec4List(List<List<int>> v, [Uint32List? data]) {
  data ??= Uint32List(v.length * 4);
  for (int i = 0; i < v.length; ++i) {
    data[i * 4 + 0] = v[i][0];
    data[i * 4 + 1] = v[i][1];
    data[i * 4 + 2] = v[i][2];
    data[i * 4 + 3] = v[i][3];
  }
  return data;
}

Float32List flattenMatrix4List(List<vm.Matrix4> v, [Float32List? data]) {
  data ??= Float32List(v.length * 16);
  for (int i = 0; i < v.length; ++i) {
    vm.Matrix4 m = v[i];
    for (int j = 0; j < 16; ++j) {
      data[i * 16 + j] = m[j];
    }
  }
  return data;
}

/// represent the raw data for mesh.
/// Internally this is wrapper around a Vertex Array Object (VAO).
/// MeshData objects can be populated directly but often they
/// will derived from **GeometryBuilder** objects.
/// The other common way to create a MeshData object is via
/// RenderProgram.makeMeshData().
/// Note, MeshData is always associated with a specific RenderProgram
/// but it is possible to assert compatibility with multiple RenderPrograms.
class MeshData extends NamedEntity {
  MeshData(String name, this._cgl, this._drawMode, this._locationMap)
    : _vao = _cgl.createVertexArray(),
      super("meshdata:$name");

  final ChronosGL _cgl;
  final GlVertexArrayObject _vao;
  final int _drawMode;
  final Map<String, GlBuffer> _buffers = {};
  final Map<String, int> _locationMap;
  GlBuffer? _indexBuffer;
  int _instances = 0;
  int _indexBufferType = -1;

  late Float32List _vertices;
  List<int>? _faces;
  final Map<String, List<num>> _attributes = {};

  void clearData() {
    for (String canonical in _buffers.keys) {
      _cgl.deleteBuffer(_buffers[canonical]!);
    }
    if (_indexBuffer != null) {
      _cgl.deleteBuffer(_indexBuffer!);
    }
  }

  void changeAttributeData(String canonical, List<num> data, int width) {
    if (debug) print("ChangeBuffer $canonical ${data.length}");
    if (canonical.codeUnitAt(0) == prefixInstancer) {
      assert(data.length ~/ width == _instances, "ChangeAttribute $_instances");
    } else {
      assert(
        data.length ~/ width == _vertices.length ~/ 3,
        "wrong size for attribute: $canonical expected: ${_vertices.length ~/ 3} got: ${data.length ~/ width}",
      );
    }
    _attributes[canonical] = data;
    _cgl.changeArrayBuffer(_buffers[canonical]!, data);
  }

  void changeVertexData(Float32List data) {
    final String canonical = aPosition;
    _vertices = data;
    changeAttributeData(canonical, data, 3);
  }

  bool supportsAttribute(String canonical) {
    return _locationMap.containsKey(canonical);
  }

  int get drawMode => _drawMode;

  int get elementArrayBufferType => _indexBufferType;

  int getNumItems() {
    if (_faces != null) {
      return _faces!.length;
    }
    return _vertices.length ~/ 3;
  }

  int getNumInstances() {
    return _instances;
  }

  List<num> getAttribute(String canonical) {
    return _attributes[canonical]!;
  }

  GlBuffer getBuffer(String canonical) {
    return _buffers[canonical]!;
  }

  void changeAttributeBuffer(String canonical, GlBuffer buffer) {
    _buffers[canonical] = buffer;
    final bool instanced = canonical.codeUnitAt(0) == prefixInstancer;
    final ShaderVarDesc desc = retrieveShaderVarDesc(canonical);
    final int index = _locationMap[canonical]!;
    _cgl.bindVertexArray(_vao);
    _cgl.enableVertexAttribArray(index, instanced ? 1 : 0);
    _cgl.vertexAttribPointer(
      buffer,
      index,
      desc.getSize(),
      glFloat,
      false,
      0,
      0,
    );
  }

  void addAttribute(String canonical, List<num> data, int width) {
    final bool instanced = canonical.codeUnitAt(0) == prefixInstancer;
    if (instanced && _instances == 0) {
      _instances = data.length ~/ width;
    }
    changeAttributeBuffer(canonical, _cgl.createBuffer());
    changeAttributeData(canonical, data, width);
  }

  void addVertices(Float32List data) {
    final String canonical = aPosition;
    changeAttributeBuffer(canonical, _cgl.createBuffer());
    changeVertexData(data);
  }

  void changeFaces(List<int> faces) {
    if (_vertices.length < 3 * 256) {
      _faces = Uint8List.fromList(faces);
      _indexBufferType = glUnsignedByte;
    } else if (_vertices.length < 3 * 65536) {
      _faces = Uint16List.fromList(faces);
      _indexBufferType = glUnsignedShort;
    } else {
      _faces = Uint32List.fromList(faces);
      _indexBufferType = glUnsignedInt;
    }

    _cgl.bindVertexArray(_vao);
    _cgl.changeElementArrayBuffer(_indexBuffer!, _faces as TypedData);
  }

  void addFaces(List<int> faces) {
    _indexBuffer = _cgl.createBuffer();
    changeFaces(faces);
  }

  void activate() {
    _cgl.bindVertexArray(_vao);
  }

  Iterable<String> getAttributes() {
    return _attributes.keys;
  }

  @override
  String toString() {
    int nf = _faces == null ? 0 : _faces!.length;
    List<String> lst = ["Faces:$nf"];
    for (String c in _attributes.keys) {
      lst.add("$c:${_attributes[c]!.length}");
    }

    return "MESH[$name] ${lst.join("  ")}";
  }
}

void _geometryBuilderAttributesToMeshData(GeometryBuilder gb, MeshData md) {
  for (String canonical in gb.attributes.keys) {
    if (!md.supportsAttribute(canonical)) {
      logInfo("Dropping unnecessary attribute: $canonical");
      continue;
    }
    List<Object> lst = gb.attributes[canonical]!;
    ShaderVarDesc desc = retrieveShaderVarDesc(canonical);

    //print("${md.name} ${canonical} ${lst}");
    switch (desc.type) {
      case varTypeVec2:
        md.addAttribute(
          canonical,
          flattenVector2List(lst as List<vm.Vector2>),
          2,
        );
        break;
      case varTypeVec3:
        md.addAttribute(
          canonical,
          flattenVector3List(lst as List<vm.Vector3>),
          3,
        );
        break;
      case varTypeVec4:
        md.addAttribute(
          canonical,
          flattenVector4List(lst as List<vm.Vector4>),
          4,
        );
        break;
      case varTypeFloat:
        md.addAttribute(
          canonical,
          Float32List.fromList(lst as List<double>),
          1,
        );
        break;
      case varTypeUvec4:
        md.addAttribute(canonical, flattenUvec4List(lst as List<List<int>>), 4);
        break;
      default:
        assert(
          false,
          "unknown type for $canonical [${lst[0].runtimeType}] [${lst.runtimeType}] $lst",
        );
    }
  }
}

MeshData geometryBuilderToMeshData(
  String name,
  RenderProgram prog,
  GeometryBuilder gb,
) {
  final DateTime start = DateTime.now();
  MeshData md = prog.makeMeshData(name, gb.pointsOnly ? glPoints : glTriangles);
  md.addVertices(flattenVector3List(gb.vertices));
  if (!gb.pointsOnly) md.addFaces(gb.generateFaceIndices());
  _geometryBuilderAttributesToMeshData(gb, md);
  final Duration delta = DateTime.now().difference(start);
  logInfo("GeometryBuilderToMeshData took ($delta) $md");
  return md;
}

MeshData _extractWireframeNormals(
  MeshData out,
  List<double> vertices,
  List<double> normals,
  double scale,
) {
  assert(vertices.length == normals.length);
  Float32List v = Float32List(2 * vertices.length);
  for (int i = 0; i < vertices.length; i += 3) {
    v[2 * i + 0] = vertices[i + 0];
    v[2 * i + 1] = vertices[i + 1];
    v[2 * i + 2] = vertices[i + 2];
    v[2 * i + 3] = vertices[i + 0] + scale * normals[i + 0];
    v[2 * i + 4] = vertices[i + 1] + scale * normals[i + 1];
    v[2 * i + 5] = vertices[i + 2] + scale * normals[i + 2];
  }
  out.addVertices(v);

  final int n = 2 * vertices.length ~/ 3;
  List<int> lines = List.generate(n, (i) => i);

  out.addFaces(lines);
  return out;
}

MeshData geometryBuilderToWireframeNormals(
  RenderProgram prog,
  GeometryBuilder gb, [
  double scale = 1.0,
]) {
  MeshData out = prog.makeMeshData("norm", glLines);
  return _extractWireframeNormals(
    out,
    flattenVector3List(gb.vertices),
    flattenVector3List(gb.attributes[aNormal] as List<vm.Vector3>),
    scale,
  );
}

//Extract Wireframe MeshData
MeshData geometryBuilderToMeshDataWireframe(
  String name,
  RenderProgram prog,
  GeometryBuilder gb,
) {
  MeshData md = prog.makeMeshData(name, glLines);
  md.addVertices(flattenVector3List(gb.vertices));
  md.addFaces(gb.generateLineIndices());
  _geometryBuilderAttributesToMeshData(gb, md);
  return md;
}

MeshData lineEndPointsToMeshData(
  String name,
  RenderProgram prog,
  List<vm.Vector3> points,
) {
  MeshData md = prog.makeMeshData(name, glLines);
  md.addVertices(flattenVector3List(points));
  List<int> faces = List.generate(points.length, (i) => i);
  md.addFaces(faces);
  return md;
}

MeshData extractWireframeNormals(
  RenderProgram prog,
  MeshData md, [
  double scale = 1.0,
]) {
  assert(md._drawMode == glTriangles, "expected GL_TRIANGLES");
  MeshData out = prog.makeMeshData(md.name, glLines);
  final Float32List vertices = md.getAttribute(aPosition) as Float32List;
  final Float32List normals = md.getAttribute(aNormal) as Float32List;
  return _extractWireframeNormals(out, vertices, normals, scale);
}

MeshData extractWireframe(RenderProgram prog, MeshData md) {
  assert(false);
  assert(md._drawMode == glTriangles);
  MeshData out = prog.makeMeshData(md.name, glLines);
  out.addVertices(md._vertices);
  final List<int> faces = md._faces!;
  // Probably wrong
  List<int> lines = List.generate(faces.length * 2, (i) => i);
  for (int i = 0; i < faces.length; i += 3) {
    lines[i * 2 + 0] = faces[i + 0];
    lines[i * 2 + 1] = faces[i + 1];
    lines[i * 2 + 2] = faces[i + 1];
    lines[i * 2 + 3] = faces[i + 2];
    lines[i * 2 + 4] = faces[i + 2];
    lines[i * 2 + 5] = faces[i + 0];
  }

  out.addFaces(lines);
  return out;
}

List<double> _getMeshFaceAreas(List<int> faces, Float32List verts) {
  vm.Vector3 v0 = vm.Vector3.zero();
  vm.Vector3 v1 = vm.Vector3.zero();
  vm.Vector3 v2 = vm.Vector3.zero();
  var areas = List<double>.filled(faces.length ~/ 3, 0.0);
  for (int f = 0; f < areas.length; ++f) {
    int i0 = faces[3 * f + 0];
    int i1 = faces[3 * f + 1];
    int i2 = faces[3 * f + 2];
    //
    v0.setValues(verts[3 * i0], verts[3 * i0 + 1], verts[3 * i0 + 2]);
    v1.setValues(verts[3 * i1], verts[3 * i1 + 1], verts[3 * i1 + 2]);
    v2.setValues(verts[3 * i2], verts[3 * i2 + 1], verts[3 * i2 + 2]);
    v1.sub(v0);
    v2.sub(v0);
    v1.crossInto(v2, v0);
    areas[f] = v0.length;
  }

  return areas;
}

double getMeshFaceArea(MeshData md) {
  List<double> areas = _getMeshFaceAreas(md._faces!, md._vertices);
  double totalArea = 0.0;
  for (var d in areas) {
    totalArea += d;
  }
  return totalArea;
}

MeshData extractPointCloud(
  RenderProgram prog,
  MeshData md,
  int numPoints, {
  bool extractNormal = true,
  bool extractColor = false,
}) {
  assert(md._drawMode == glTriangles, "expected GL_TRIANGLES");
  if (extractNormal) {
    assert(md.supportsAttribute(aNormal), "expected support for aNormal");
  }
  if (extractColor) {
    assert(md.supportsAttribute(aColor), "expected support for aColor");
  }
  final List<int> faces = md._faces!;
  final Float32List verts = md._vertices;
  final Float32List norms = extractNormal
      ? md.getAttribute(aNormal) as Float32List
      : Float32List(0);
  if (extractNormal) {
    assert(norms.length == verts.length);
  }
  final Float32List cols = extractColor
      ? md.getAttribute(aColor) as Float32List
      : Float32List(0);
  if (extractColor) {
    assert(cols.length == verts.length);
  }

  vm.Vector3 v0 = vm.Vector3.zero();
  vm.Vector3 v1 = vm.Vector3.zero();
  vm.Vector3 v2 = vm.Vector3.zero();
  vm.Vector3 n0 = vm.Vector3.zero();
  vm.Vector3 n1 = vm.Vector3.zero();
  vm.Vector3 n2 = vm.Vector3.zero();
  vm.Vector3 c0 = vm.Vector3.zero();
  vm.Vector3 c1 = vm.Vector3.zero();
  vm.Vector3 c2 = vm.Vector3.zero();

  void getVertsForFace(int f) {
    int i0 = faces[3 * f + 0];
    int i1 = faces[3 * f + 1];
    int i2 = faces[3 * f + 2];
    //
    v0.setValues(verts[3 * i0], verts[3 * i0 + 1], verts[3 * i0 + 2]);
    v1.setValues(verts[3 * i1], verts[3 * i1 + 1], verts[3 * i1 + 2]);
    v2.setValues(verts[3 * i2], verts[3 * i2 + 1], verts[3 * i2 + 2]);
    //
    if (extractNormal) {
      n0.setValues(norms[3 * i0], norms[3 * i0 + 1], norms[3 * i0 + 2]);
      n1.setValues(norms[3 * i1], norms[3 * i1 + 1], norms[3 * i1 + 2]);
      n2.setValues(norms[3 * i2], norms[3 * i2 + 1], norms[3 * i2 + 2]);
    }
    if (extractColor) {
      c0.setValues(cols[3 * i0], cols[3 * i0 + 1], cols[3 * i0 + 2]);
      c1.setValues(cols[3 * i1], cols[3 * i1 + 1], cols[3 * i1 + 2]);
      c2.setValues(cols[3 * i2], cols[3 * i2 + 1], cols[3 * i2 + 2]);
    }
  }

  List<double> areas = _getMeshFaceAreas(faces, verts);
  double totalArea = 0.0;
  for (var d in areas) {
    totalArea += d;
  }
  print(
    "vertices: ${md._vertices.length ~/ 3}  faces: ${faces.length}  total: $totalArea",
  );
  final double areaPerPoint = totalArea / numPoints;
  double ceiling = 0.0;
  int currentFace = 0;
  ceiling += areas[currentFace];
  getVertsForFace(currentFace);

  var rng = math.Random();
  Float32List sampledVerts = Float32List(3 * numPoints);
  Float32List sampledNorms = Float32List(3 * numPoints);
  Float32List sampledCols = Float32List(3 * numPoints);

  for (int i = 0; i < numPoints; ++i) {
    double x = i * areaPerPoint;
    while (x > ceiling) {
      ++currentFace;
      ceiling += areas[currentFace];
      getVertsForFace(currentFace);
    }
    // https://chrischoy.github.io/research/barycentric-coordinate-for-mesh-sampling/
    // Random sampling is easy but not really what we want.
    // We want uniform covering
    double sqrtU = math.sqrt(rng.nextDouble());
    double v = rng.nextDouble();

    double a = 1 - sqrtU;
    double b = sqrtU - sqrtU * v;
    double c = sqrtU * v;
    sampledVerts[3 * i + 0] = a * v0.x + b * v1.x + c * v2.x;
    sampledVerts[3 * i + 1] = a * v0.y + b * v1.y + c * v2.y;
    sampledVerts[3 * i + 2] = a * v0.z + b * v1.z + c * v2.z;
    //
    if (extractNormal) {
      sampledNorms[3 * i + 0] = a * n0.x + b * n1.x + c * n2.x;
      sampledNorms[3 * i + 1] = a * n0.y + b * n1.y + c * n2.y;
      sampledNorms[3 * i + 2] = a * n0.z + b * n1.z + c * n2.z;
    }
    if (extractColor) {
      sampledCols[3 * i + 0] = a * c0.r + b * c1.r + c * c2.r;
      sampledCols[3 * i + 1] = a * c0.g + b * c1.g + c * c2.g;
      sampledCols[3 * i + 2] = a * c0.b + b * c1.b + c * c2.b;
    }
  }
  MeshData out = prog.makeMeshData(md.name, glPoints);
  out.addVertices(sampledVerts);
  if (extractNormal) {
    out.addAttribute(aNormal, sampledNorms, 3);
  }
  if (extractColor) {
    out.addAttribute(aColor, sampledCols, 3);
  }
  return out;
}
