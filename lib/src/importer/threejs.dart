part of 'lib.dart';

int _findSkinMultiplier(Map<String, Object?> json) {
  final skinIndex = json["skinIndices"] as List<Object?>?;
  final skinWeight = json["skinWeights"] as List<Object?>?;
  if (skinIndex == null || skinIndex.isEmpty) return 0;
  final int vertexLength = _jsonList(json["vertices"]).length ~/ 3;
  final int skinMultiplier = skinIndex.length ~/ vertexLength;

  assert(vertexLength * skinMultiplier == skinIndex.length);
  assert(vertexLength * skinMultiplier == skinWeight!.length);
  assert(skinMultiplier <= 4);
  print("Skin multiplier is $skinMultiplier");
  return skinMultiplier;
}

List<GeometryBuilder> importGeometryFromThreeJsJson(Map<String, Object?> json) {
  List<GeometryBuilder> out = [];
  //
  final int skinMultiplier = _findSkinMultiplier(json);
  final List<int> faces = _intify(_jsonList(json["faces"]));
  print("faces: ${faces.length}");

  final List<vm.Vector3> vertices = convertToVector3List(
    _jsonList(json["vertices"]),
  );
  final List<vm.Vector3> normals = convertToVector3List(
    _jsonList(json["normals"]),
  );
  final List<vm.Vector4>? skinIndex = skinMultiplier == 0
      ? null
      : convertToVector4List(skinMultiplier, _jsonList(json["skinIndices"]));

  final List<vm.Vector4>? skinWeight = skinMultiplier == 0
      ? null
      : convertToVector4List(
          skinMultiplier,
          _floatify(_jsonList(json["skinWeights"])),
        );
  if (skinWeight != null) {
    for (vm.Vector4 v in skinWeight) {
      final double d = v.x + v.y + v.z + v.w;
      if (d < 0.98 || d > 1.02) {
        print("bad vector: $v");
      }
    }
  }
  // TODO: support for more than one
  final List<vm.Vector2> uvs = convertToVector2List(
    _jsonList(_jsonList(json["uvs"])[0]),
  );
  // TODO: support incomplete
  //final List Colors = json["colors"];

  int i = 0;
  while (i < faces.length) {
    final int t = faces[i++];
    final int d = (t & 1) == 0 ? 3 : 4; // quad or triangle
    final bool hasMaterial = (t & 2) != 0;
    final bool hasFaceVertexUv = (t & 8) != 0;
    final bool hasFaceNormal = (t & 16) != 0;
    final bool hasFaceVertexNormal = (t & 32) != 0;
    final bool hasFaceColor = (t & 64) != 0;
    final bool hasFaceVertexColor = (t & 128) != 0;

    List<int> indices = [];
    for (int j = 0; j < d; j++) {
      indices.add(faces[i++]);
    }

    int mat = 0;
    if (hasMaterial) {
      mat = faces[i++];
    }

    List<vm.Vector2> uv = [];
    if (hasFaceVertexUv) {
      for (int j = 0; j < d; j++) {
        uv.add(uvs[faces[i++]]);
      }
    }

    List<vm.Vector3> normal = [];
    if (hasFaceNormal) {
      vm.Vector3 norm = normals[faces[i++]];
      for (int j = 0; j < d; j++) {
        normal.add(norm);
      }
    }

    if (hasFaceVertexNormal) {
      for (int j = 0; j < d; j++) {
        normal.add(normals[faces[i++]]);
      }
    }

    List<int> color = [];
    if (hasFaceColor) {
      assert(false);
      int col = faces[i++];
      for (int j = 0; j < d; j++) {
        color.add(col);
      }
    }

    if (hasFaceVertexColor) {
      assert(false);
      for (int j = 0; j < d; j++) {
        color.add(faces[i++]);
      }
    }

    while (out.length <= mat) {
      GeometryBuilder gb = GeometryBuilder();
      if (normals.isNotEmpty) gb.enableAttribute(aNormal);
      if (uvs.isNotEmpty) gb.enableAttribute(aTexUV);
      if (skinMultiplier > 0) {
        gb.enableAttribute(aBoneIndex);
        gb.enableAttribute(aBoneWeight);
      }
      out.add(gb);
    }
    GeometryBuilder gb = out[mat];
    List<vm.Vector3> vertex = [];

    for (int i in indices) {
      vertex.add(vertices[i]);
    }

    if (d == 3) {
      gb.addVerticesFace3(vertex);
    } else {
      assert(d == 4);
      gb.addVerticesFace4(vertex);
    }
    if (uv.isNotEmpty) {
      gb.addAttributesVector2(aTexUV, uv);
    }
    if (normal.isNotEmpty) {
      gb.addAttributesVector3(aNormal, normal);
    }

    if (skinMultiplier > 0) {
      assert(vertices.length == skinIndex!.length);
      assert(vertices.length == skinWeight!.length);

      List<vm.Vector4> boneIndex = [];
      List<vm.Vector4> boneWeight = [];
      for (int i in indices) {
        boneIndex.add(skinIndex![i]);
        boneWeight.add(skinWeight![i]);
      }
      gb.addAttributesVector4(aBoneIndex, boneIndex);
      gb.addAttributesVector4(aBoneWeight, boneWeight);
    }
  }

  print("out: ${out.length} ${out[0]}");
  return out;
}

SkeletalAnimation importAnimationFromThreeJsJson(
  Map<String, Object?> json,
  List<Bone> skeleton,
) {
  final animation = _jsonMap(json["animation"]);
  final hierarchy = _jsonObjects(animation["hierarchy"]).toList();
  SkeletalAnimation s = SkeletalAnimation(
    animation["name"] as String,
    _jsonDouble(animation["length"]),
    hierarchy.length,
  );
  assert(hierarchy.length == _jsonList(json["bones"]).length);
  for (int i = 0; i < hierarchy.length; ++i) {
    List<double> pTimes = [];
    List<vm.Vector3> pValues = [];
    List<double> rTimes = [];
    List<vm.Quaternion> rValues = [];
    List<double> sTimes = [];
    List<vm.Vector3> sValues = [];
    for (final m in _jsonObjects(hierarchy[i]["keys"])) {
      double t = _jsonDouble(m["time"]);

      if (m.containsKey("pos")) {
        pTimes.add(t);
        pValues.add(makeTransVector3(m["pos"] as List<Object?>?));
      }

      if (m.containsKey("scale")) {
        sTimes.add(t);
        sValues.add(makeScaleVector3(m["scl"] as List<Object?>?));
      }

      if (m.containsKey("rot")) {
        rTimes.add(t);
        rValues.add(makeQuaternion(m["rot"] as List<Object?>?));
      }
    }
    BoneAnimation ba = BoneAnimation(
      skeleton[i],
      pTimes,
      pValues,
      rTimes,
      rValues,
      sTimes,
      sValues,
    );
    s.insertBone(ba);
  }
  print("anim-bones: ${s.animList.length}");
  return s;
}

List<Bone> importSkeletonFromThreeJsJson(Map<String, Object?> json) {
  final metadata = _jsonMap(json["metadata"]);
  final bones = _jsonObjects(json["bones"]).toList();
  assert(bones.length == metadata["bones"]);
  List<Bone> out = List.generate(bones.length, (i) {
    final m = bones[i];
    String name = m["name"] as String;
    int parent = m["parent"] as int;
    final vm.Vector3 s = makeScaleVector3(m["scl"] as List<Object?>?);
    final vm.Vector3 t = makeTransVector3(m["pos"] as List<Object?>?);
    final vm.Quaternion r = makeQuaternion(m["rotq"] as List<Object?>?);
    vm.Matrix4 mat = vm.Matrix4.zero()
      ..setFromTranslationRotationScale(t, r, s);
    if (i != 0 && parent < 0) {
      print("found unusal root node $i $parent");
    }
    return Bone(name, i, parent, mat, vm.Matrix4.identity());
  });
  print("bones: ${out.length}");
  recomputeLocalOffsets(out);
  return out;
}
