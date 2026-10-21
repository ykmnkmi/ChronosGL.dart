part of 'lib.dart';

class Face1 {
  Face1(this.a);

  int a;
}

class Face2 {
  Face2(this.a, this.b);

  int a, b;
}

class Face3 {
  Face3(this.a, this.b, this.c);

  int a, b, c;
}

class Face4 {
  Face4(this.a, this.b, this.c, this.d);

  int a, b, c, d;
}

bool normalFromPoints(
  vm.Vector3 a,
  vm.Vector3 b,
  vm.Vector3 c,
  vm.Vector3 temp,
  vm.Vector3 normal,
) {
  temp
    ..setFrom(b)
    ..sub(a);
  normal
    ..setFrom(c)
    ..sub(a);

  normal.crossInto(temp, normal);

  double len = normal.length;
  if (len == 0) {
    return false;
  }

  normal.scale(-1 / len); // normalize // added the minus to make it the correct normal compared to the base cube

  return true;
}

// Note: the build-in has does not work of all components are close to zero.
int hashVector3(vm.Vector3 v) {
  int h = 0;
  for (int i in v.storage.buffer.asInt32List()) {
    h ^= i;
  }
  return h;
}

class Edge3 {
  Edge3(this.v1, this.v2);

  final vm.Vector3 v1;
  final vm.Vector3 v2;

  @override
  String toString() => "$v1 -> $v2";

  @override
  bool operator ==(Object other) =>
      other is Edge3 && v1 == other.v1 && v2 == other.v2;

  @override
  int get hashCode => hashVector3(v1) ^ hashVector3(v2);
}

/// Helper for Shader independent Mesh creation.
/// Supports Faces with 3 and 4 Nodes or point clouds.
/// Use  geometryBuilderToMeshData() to create the Mesh
/// for a specific Shader.
class GeometryBuilder {
  GeometryBuilder([this.pointsOnly = false]);

  // if true we have have point cloud
  final bool pointsOnly;
  final List<Face3> faces3 = []; // only used if pointsOnly == false
  final List<Face4> faces4 = []; // only used if pointsOnly == false
  final List<vm.Vector3> vertices = [];
  final Map<String, List<Object>> attributes = {};

  void enableAttribute(String canonical) {
    assert(
      !attributes.containsKey(canonical),
      "attribute $canonical already exists",
    );
    assert(canonical.startsWith("a"), "$canonical is not an attribute");
    ShaderVarDesc desc = retrieveShaderVarDesc(canonical);
    switch (desc.type) {
      case varTypeVec2:
        attributes[canonical] = <vm.Vector2>[];
        break;
      case varTypeVec3:
        attributes[canonical] = <vm.Vector3>[];
        break;
      case varTypeVec4:
        attributes[canonical] = <vm.Vector4>[];
        break;
      case varTypeFloat:
        attributes[canonical] = <double>[];
        break;
      case varTypeUvec4:
        attributes[canonical] = <List<int>>[];
        break;
      default:
        assert(false, "unknown type for $canonical");
    }
  }

  bool isEmpty() {
    return faces3.isEmpty && faces4.isEmpty && vertices.isEmpty;
  }

  bool hasAttribute(String canonical) {
    return attributes.containsKey(canonical);
  }

  // Note: the normal matrix should be a submatrix mat
  void applyTransform([vm.Matrix4? mat, vm.Matrix3? matNormal]) {
    if (attributes.containsKey(aNormal)) {
      assert(matNormal != null, "no normal matrix provided");
      for (vm.Vector3 v in attributes[aNormal] as List<vm.Vector3>) {
        v.applyMatrix3(matNormal!);
      }
    }
    if (mat != null) {
      for (vm.Vector3 v in vertices) {
        v.applyMatrix4(mat);
      }
    }
  }

  // Same as above but use Quaternions + translation
  void applyTransform2(vm.Quaternion rot, vm.Vector3 translate) {
    if (attributes.containsKey(aNormal)) {
      for (vm.Vector3 v in attributes[aNormal] as List<vm.Vector3>) {
        v.applyQuaternion(rot);
      }
    }

    for (vm.Vector3 v in vertices) {
      v.applyQuaternion(rot);
      v.add(translate);
    }
  }

  // Simple means the vertex coordinated in other are not changed
  void mergeAndTakeOwnershipSimple(GeometryBuilder other) {
    if (other.vertices.isEmpty) return;
    final int offset = vertices.length;

    assert(pointsOnly == other.pointsOnly);
    for (String a in attributes.keys) {
      assert(other.attributes.containsKey(a));
    }

    if (isEmpty()) {
      for (String a in other.attributes.keys) {
        attributes[a] = other.attributes[a]!;
      }
    } else {
      for (String a in other.attributes.keys) {
        assert(attributes.containsKey(a), "missing attribute $a");
        attributes[a]!.addAll(other.attributes[a]!);
      }
    }
    other.attributes.clear();

    vertices.addAll(other.vertices);
    other.vertices.clear();

    for (Face3 face in other.faces3) {
      face.a += offset;
      face.b += offset;
      face.c += offset;
      faces3.add(face);
    }
    other.faces3.clear();

    for (Face4 face in other.faces4) {
      face.a += offset;
      face.b += offset;
      face.c += offset;
      face.d += offset;
      faces4.add(face);
    }
    other.faces4.clear();
  }

  void sanityCheck() {
    if (pointsOnly) {
      assert(faces3.isEmpty);
      assert(faces4.isEmpty);
      return;
    }
    int maxIndexFace3 = -1;
    for (Face3 f in faces3) {
      if (f.a > maxIndexFace3) maxIndexFace3 = f.a;
      if (f.b > maxIndexFace3) maxIndexFace3 = f.b;
      if (f.c > maxIndexFace3) maxIndexFace3 = f.c;
    }

    int maxIndexFace4 = -1;
    for (Face4 f in faces4) {
      if (f.a > maxIndexFace4) maxIndexFace4 = f.a;
      if (f.b > maxIndexFace4) maxIndexFace4 = f.b;
      if (f.c > maxIndexFace4) maxIndexFace4 = f.c;
      if (f.d > maxIndexFace4) maxIndexFace4 = f.d;
    }

    final int n = vertices.length;
    assert(n >= 0);
    assert(maxIndexFace3 < n, "$maxIndexFace3 vs $n");
    assert(maxIndexFace4 < n, "$maxIndexFace4 vs $n");

    for (String canonical in attributes.keys) {
      assert(
        attributes[canonical]!.length == vertices.length,
        "bad attribute $canonical",
      );
    }
  }

  void mergeAndTakeOwnership(
    GeometryBuilder other, [
    vm.Matrix4? mat,
    vm.Matrix3? matNormal,
  ]) {
    other.applyTransform(mat, matNormal);
    mergeAndTakeOwnershipSimple(other);
  }

  void mergeAndTakeOwnership2(
    GeometryBuilder other,
    vm.Quaternion rot,
    vm.Vector3 translation,
  ) {
    other.applyTransform2(rot, translation);
    mergeAndTakeOwnershipSimple(other);
  }

  void addFace3(int a, int b, int c, [bool reverse = false]) {
    assert(pointsOnly == false, "pointsOnly must be false");
    faces3.add(reverse ? Face3(c, b, a) : Face3(a, b, c));
  }

  void addFace4(int a, int b, int c, int d, [bool reverse = false]) {
    assert(pointsOnly == false, "pointsOnly must be false");
    faces4.add(reverse ? Face4(d, c, b, a) : Face4(a, b, c, d));
  }

  void addFaces3(int n, [bool reverse = false]) {
    assert(pointsOnly == false, "pointsOnly must be false");

    int v = vertices.length;
    for (int i = 0; i < n; i++, v += 3) {
      addFace3(v + 0, v + 1, v + 2, reverse);
    }
  }

  void addFaces4(int n, [bool reverse = false]) {
    assert(pointsOnly == false);
    int v = vertices.length;
    for (int i = 0; i < n; i++, v += 4) {
      addFace4(v + 0, v + 1, v + 2, v + 3, reverse);
    }
  }

  // Extract the triplets from vertex
  int addVertices(List<vm.Vector3> vs) {
    int size = vertices.length;
    for (vm.Vector3 v in vs) {
      vertices.add(v.clone());
    }
    return size;
  }

  int addVerticesTakeOwnership(List<vm.Vector3> vs) {
    int size = vertices.length;
    for (vm.Vector3 v in vs) {
      vertices.add(v);
    }
    return size;
  }

  int addVertex(vm.Vector3 v) {
    int size = vertices.length;
    vertices.add(v.clone());
    return size;
  }

  int addVertexTakeOwnership(vm.Vector3 v) {
    int size = vertices.length;
    vertices.add(v);
    return size;
  }

  void addVerticesFace3(List<vm.Vector3> vs) {
    assert(vs.length == 3);
    int i = vertices.length;
    addFace3(i + 0, i + 1, i + 2);
    addVertices(vs);
  }

  void addVerticesFace3TakeOwnership(List<vm.Vector3> vs) {
    assert(vs.length == 3);
    int i = vertices.length;
    addFace3(i + 0, i + 1, i + 2);
    addVerticesTakeOwnership(vs);
  }

  void addAttributeDouble(String canonical, double v) {
    attributes[canonical]!.add(v);
  }

  void addAttributesDouble(String canonical, List<double> lst) {
    attributes[canonical]!.addAll(lst);
  }

  void addAttributeVector2(String canonical, vm.Vector2 v) {
    attributes[canonical]!.add(v.clone());
  }

  void addAttributesVector2(String canonical, List<vm.Vector2> lst) {
    List<vm.Vector2> ts = attributes[canonical] as List<vm.Vector2>;
    for (vm.Vector2 v in lst) {
      ts.add(v.clone());
    }
  }

  void addAttributesVector2TakeOwnership(
    String canonical,
    List<vm.Vector2> lst,
  ) {
    attributes[canonical]!.addAll(lst);
  }

  void addAttributeVector3(String canonical, vm.Vector3 v) {
    List<vm.Vector3> ts = attributes[canonical] as List<vm.Vector3>;
    ts.add(v.clone());
  }

  void addAttributesVector3(String canonical, List<vm.Vector3> lst) {
    List<vm.Vector3> ts = attributes[canonical] as List<vm.Vector3>;
    for (vm.Vector3 v in lst) {
      ts.add(v.clone());
    }
  }

  void addAttributesVector3TakeOwnership(
    String canonical,
    List<vm.Vector3> lst,
  ) {
    List<vm.Vector3> ts = attributes[canonical] as List<vm.Vector3>;
    ts.addAll(lst);
  }

  void addAttributeVector4(String canonical, vm.Vector4 v) {
    List<vm.Vector4> ts = attributes[canonical] as List<vm.Vector4>;
    ts.add(v.clone());
  }

  void addAttributesVector4(String canonical, List<vm.Vector4> lst) {
    List<vm.Vector4> ts = attributes[canonical] as List<vm.Vector4>;
    for (vm.Vector4 v in lst) {
      ts.add(v.clone());
    }
  }

  void addAttributesVector4TakeOwnership(
    String canonical,
    List<vm.Vector4> lst,
  ) {
    List<vm.Vector4> ts = attributes[canonical] as List<vm.Vector4>;
    ts.addAll(lst);
  }

  void addAttributesUvec4(String canonical, List<List<int>> lst) {
    List<List<int>> ts = attributes[canonical] as List<List<int>>;
    for (List<int> v in lst) {
      ts.add(v.sublist(0));
    }
  }

  void addVerticesFace4(List<vm.Vector3> vs) {
    assert(vs.length == 4);
    int i = vertices.length;
    addFace4(i + 0, i + 1, i + 2, i + 3);
    addVertices(vs);
  }

  void addVerticesFace4TakeOwnership(List<vm.Vector3> vs) {
    assert(vs.length == 4);
    int i = vertices.length;
    addFace4(i + 0, i + 1, i + 2, i + 3);
    addVerticesTakeOwnership(vs);
  }

  void addFaces4Strip(List<vm.Vector3> top, List<vm.Vector3> bot, bool closed) {
    assert(top.length == bot.length);
    final n = top.length - 1;
    for (int i = 0; i < n; ++i) {
      addVerticesFace4([bot[i], bot[i + 1], top[i + 1], top[i]]);
    }
    if (closed) {
      addVerticesFace4([bot[n], bot[0], top[0], top[n]]);
    }
  }

  void addFaces4Strips(
    List<List<vm.Vector3>> strips,
    bool closed, [
    bool flip = false,
  ]) {
    for (int i = 0; i < strips.length - 1; ++i) {
      if (flip) {
        addFaces4Strip(strips[i], strips[i + 1], closed);
      } else {
        addFaces4Strip(strips[i + 1], strips[i], closed);
      }
    }
  }

  // generateFaces is usually only called once to initialize _faces.
  // Its main purpose is to convert Face4 into two triangles
  List<int> generateFaceIndices() {
    assert(faces3.isNotEmpty || faces4.isNotEmpty);
    List<int> faces = List.generate(
      faces3.length * 3 + faces4.length * 6,
      (i) => 0,
    );
    int i = 0;
    for (Face3 f3 in faces3) {
      faces[i + 0] = f3.a;
      faces[i + 1] = f3.b;
      faces[i + 2] = f3.c;
      i += 3;
    }
    for (Face4 f4 in faces4) {
      faces[i + 0] = f4.a;
      faces[i + 1] = f4.b;
      faces[i + 2] = f4.c;
      //
      faces[i + 3] = f4.a;
      faces[i + 4] = f4.c;
      faces[i + 5] = f4.d;
      i += 6;
    }
    assert(i == faces.length);
    return faces;
  }

  List<int> generateLineIndices() {
    List<int> lines = List.generate(
      faces3.length * 6 + faces4.length * 8,
      (i) => 0,
    );
    int i = 0;
    for (Face3 f3 in faces3) {
      lines[i + 0] = f3.a;
      lines[i + 1] = f3.b;
      lines[i + 2] = f3.b;
      lines[i + 3] = f3.c;
      lines[i + 4] = f3.c;
      lines[i + 5] = f3.a;
      i += 6;
    }
    for (Face4 f4 in faces4) {
      lines[i + 0] = f4.a;
      lines[i + 1] = f4.b;
      lines[i + 2] = f4.b;
      lines[i + 3] = f4.c;
      lines[i + 4] = f4.c;
      lines[i + 5] = f4.d;
      lines[i + 6] = f4.d;
      lines[i + 7] = f4.a;
      i += 8;
    }
    assert(i == lines.length);
    return lines;
  }

  void generateNormalsAssumingTriangleMode() {
    List<vm.Vector3> normals = List.generate(
      vertices.length,
      (i) => vm.Vector3.zero(),
    );
    vm.Vector3 temp = vm.Vector3.zero();
    vm.Vector3 norm = vm.Vector3.zero();
    for (Face3 f3 in faces3) {
      normalFromPoints(
        vertices[f3.a],
        vertices[f3.b],
        vertices[f3.c],
        temp,
        norm,
      );
      normals[f3.a] = norm.clone();
      normals[f3.b] = norm.clone();
      normals[f3.c] = norm.clone();
    }

    for (Face4 f4 in faces4) {
      normalFromPoints(
        vertices[f4.a],
        vertices[f4.b],
        vertices[f4.c],
        temp,
        norm,
      );
      normals[f4.a] = norm.clone();
      normals[f4.b] = norm.clone();
      normals[f4.c] = norm.clone();
      normals[f4.d] = norm.clone();
    }
    attributes[aNormal] = normals;
  }

  // TODO: this needs more work and may never work well
  void generateAveragedNormalsAssumingTriangleMode() {
    Map<vm.Vector3, vm.Vector3> avg = <vm.Vector3, vm.Vector3>{};
    //Map<vm.Vector3, double> cnt = {};
    vm.Vector3 temp = vm.Vector3.zero();
    vm.Vector3 norm = vm.Vector3.zero();

    void add(int index, vm.Vector3 n) {
      vm.Vector3 v = vertices[index];
      if (avg.containsKey(v)) {
        avg[v] = avg[n]! + n;
        //cnt[v]++;
      } else {
        avg[v] = n;
        //cnt[v] = 1;
      }
    }

    for (Face3 f3 in faces3) {
      normalFromPoints(
        vertices[f3.a],
        vertices[f3.b],
        vertices[f3.c],
        temp,
        norm,
      );
      vm.Vector3 n = norm.clone();
      add(f3.a, n);
      add(f3.b, n);
      add(f3.c, n);
    }

    for (Face4 f4 in faces4) {
      normalFromPoints(
        vertices[f4.a],
        vertices[f4.b],
        vertices[f4.c],
        temp,
        norm,
      );
      vm.Vector3 n = norm.clone()..scale(2.0);
      add(f4.a, n);
      add(f4.b, n);
      add(f4.c, n);
      add(f4.d, n);
    }

    for (vm.Vector3 key in avg.keys) {
      avg[key] = avg[key]!..normalize();
    }
    List<vm.Vector3> normals = List.generate(
      vertices.length,
      (i) => avg[vertices[i]]!,
    );

    attributes[aNormal] = normals;
  }

  void generateRadialNormals(vm.Vector3 center) {
    vm.Vector3 norm = vm.Vector3.zero();
    List<vm.Vector3> normals = List.generate(vertices.length, (i) {
      norm = vertices[i] - center;
      norm.normalize();
      return norm.clone();
    });
    attributes[aNormal] = normals;
  }

  // populate aCenter Input
  void generateWireframeCenters() {
    List<vm.Vector4> center = List.generate(
      vertices.length,
      (i) => vm.Vector4.zero(),
    );

    vm.Vector4 a3 = vm.Vector4(1.0, 0.0, 0.0, 0.0);
    vm.Vector4 b3 = vm.Vector4(0.0, 1.0, 0.0, 0.0);
    vm.Vector4 c3 = vm.Vector4(0.0, 0.0, 1.0, 0.0);

    for (Face3 f in faces3) {
      center[f.a] = a3.clone();
      center[f.b] = b3.clone();
      center[f.c] = c3.clone();
    }

    vm.Vector4 a4 = vm.Vector4(1.0, 0.0, 0.0, 1.0);
    vm.Vector4 b4 = vm.Vector4(1.0, 1.0, 0.0, 1.0);
    vm.Vector4 c4 = vm.Vector4(0.0, 1.0, 0.0, 1.0);
    vm.Vector4 d4 = vm.Vector4(0.0, 0.0, 0.0, 1.0);

    for (Face4 f in faces4) {
      center[f.a] = a4.clone();
      center[f.b] = b4.clone();
      center[f.c] = c4.clone();
      center[f.d] = d4.clone();
    }
    attributes[aCenter] = center;
  }

  /// w: num horizontal points
  /// h: num vertical points
  void generateRegularGridUV(int w, int h) {
    assert(vertices.length == w * h, "grid vertices length mismatch");
    List<vm.Vector2> uvs = [];
    attributes[aTexUV] = uvs;

    for (int y = h - 1; y >= 0; --y) {
      for (int x = 0; x < w; ++x) {
        // we interchange x and y for historical reasons here
        uvs.add(vm.Vector2(y / (h - 1), x / (w - 1)));
      }
    }
    assert(uvs.length == w * h, "grid uvs lengths mismatch");
  }

  void generateRegularGridFaces(
    int w,
    int h,
    bool wrapped, [
    bool reverse = false,
  ]) {
    assert(vertices.length == w * h);
    for (int i = 0; i < h - (wrapped ? 0 : 1); ++i) {
      for (int j = 0; j < w - (wrapped ? 0 : 1); ++j) {
        int ip = i + 1;
        int jp = j + 1;
        if (wrapped) {
          ip = ip % h;
          jp = jp % w;
        }
        addFace4(i * w + jp, ip * w + jp, ip * w + j, i * w + j, reverse);
      }
    }
    if (wrapped) {
      assert(faces4.length == w * h, "face4 length mismatch");
    } else {
      assert(faces4.length == (w - 1) * (h - 1), "face4 length mismatch");
    }
  }

  // http://pages.mtu.edu/~shene/COURSES/cs3621/SLIDES/Mesh.pdf
  bool isOrientableManifoldWithBoundaries() {
    final LinkedHashMap<Edge3, Object> incidenceE =
        LinkedHashMap<Edge3, Object>();

    bool addEdge(vm.Vector3 v1, vm.Vector3 v2, Object face) {
      final Edge3 edge = Edge3(v1, v2);

      final Object f = incidenceE.putIfAbsent(edge, () => face);
      if (f != face) {
        logWarn("unexpected duplicate edge:  $edge");
        return true;
      } else {
        return false;
      }
    }

    for (Face3 f3 in faces3) {
      vm.Vector3 va = vertices[f3.a];
      vm.Vector3 vb = vertices[f3.b];
      vm.Vector3 vc = vertices[f3.c];
      if (addEdge(va, vb, f3) | addEdge(vb, vc, f3) | addEdge(vc, va, f3)) {
        return false;
      }
    }

    for (Face4 f4 in faces4) {
      vm.Vector3 va = vertices[f4.a];
      vm.Vector3 vb = vertices[f4.b];
      vm.Vector3 vc = vertices[f4.c];
      vm.Vector3 vd = vertices[f4.d];
      if (addEdge(va, vb, f4) |
          addEdge(vb, vc, f4) |
          addEdge(vc, va, f4) |
          // same split as in  generateFaceIndices()
          addEdge(va, vc, f4) |
          addEdge(vc, vd, f4) |
          addEdge(vd, va, f4)) {
        return false;
      }
    }
    // check that each edge is incident to two faces with compatible orientation
    for (Edge3 e in incidenceE.keys) {
      Edge3 f = Edge3(e.v2, e.v1);
      if (!incidenceE.containsKey(f)) {
        logWarn("unpaired edge ${e.v1}->${e.v2}");
        return false;
      }
    }

    // fan property
    // print("build incidenceV from ${incidenceE.length} edges");
    final LinkedHashMap<vm.Vector3, List<vm.Vector3>> incidenceV =
        LinkedHashMap<vm.Vector3, List<vm.Vector3>>(hashCode: hashVector3);
    for (Edge3 e in incidenceE.keys) {
      incidenceV.putIfAbsent(e.v1, () => <vm.Vector3>[]).add(e.v2);
    }

    bool formsLoop(List<vm.Vector3> lst) {
      for (int i = 0; i < lst.length; ++i) {
        vm.Vector3 v1 = i == 0 ? lst.last : lst[i - 1];
        // print("fan ${v1} ${lst}");
        bool found = false;
        for (int j = i; j < lst.length; ++j) {
          vm.Vector3 v2 = lst[j];
          if (incidenceE.containsKey(Edge3(v1, v2))) {
            lst[j] = lst[i];
            lst[i] = v2;
            found = true;
            break;
          }
        }
        if (!found) {
          return false;
        }
      }
      return true;
    }

    //print ("check loops");
    for (List<vm.Vector3> lst in incidenceV.values) {
      if (!formsLoop(lst)) {
        logWarn("fan issues for $lst");
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    List<String> s = [
      "GB:",
      "V[${vertices.length}]",
      "f3[${faces3.length}]",
      "f4[${faces4.length}]",
    ];
    for (String canonical in attributes.keys) {
      String type = retrieveShaderVarDesc(canonical).type;
      s.add("$canonical[$type,${attributes[canonical]!.length}]");
    }
    return s.join(" ");
  }
}
