part of 'lib.dart';

int _FindSkinMultiplier(Map<String, Object?> json) {
  final SkinIndex = json["skinIndices"] as List<Object?>?;
  final SkinWeight = json["skinWeights"] as List<Object?>?;
  if (SkinIndex == null || SkinIndex.isEmpty) return 0;
  final int vertexLength = _JsonList(json["vertices"]).length ~/ 3;
  final int skinMultiplier = SkinIndex.length ~/ vertexLength;

  assert(vertexLength * skinMultiplier == SkinIndex.length);
  assert(vertexLength * skinMultiplier == SkinWeight!.length);
  assert(skinMultiplier <= 4);
  print("Skin multiplier is $skinMultiplier");
  return skinMultiplier;
}

List<GeometryBuilder> ImportGeometryFromThreeJsJson(Map<String, Object?> json) {
  List<GeometryBuilder> out = [];
  //
  final int skinMultiplier = _FindSkinMultiplier(json);
  final List<int> Faces = _Intify(_JsonList(json["faces"]));
  print("faces: ${Faces.length}");

  final List<VM.Vector3> Vertices = ConvertToVector3List(
    _JsonList(json["vertices"]),
  );
  final List<VM.Vector3> Normals = ConvertToVector3List(
    _JsonList(json["normals"]),
  );
  final List<VM.Vector4>? SkinIndex = skinMultiplier == 0
      ? null
      : ConvertToVector4List(skinMultiplier, _JsonList(json["skinIndices"]));

  final List<VM.Vector4>? SkinWeight = skinMultiplier == 0
      ? null
      : ConvertToVector4List(
          skinMultiplier,
          _Floatify(_JsonList(json["skinWeights"])),
        );
  if (SkinWeight != null) {
    for (VM.Vector4 v in SkinWeight) {
      final double d = v.x + v.y + v.z + v.w;
      if (d < 0.98 || d > 1.02) {
        print("bad vector: $v");
      }
    }
  }
  // TODO: support for more than one
  final List<VM.Vector2> Uvs = ConvertToVector2List(
    _JsonList(_JsonList(json["uvs"])[0]),
  );
  // TODO: support incomplete
  //final List Colors = json["colors"];

  int i = 0;
  while (i < Faces.length) {
    final int t = Faces[i++];
    final int d = (t & 1) == 0 ? 3 : 4; // quad or triangle
    final bool hasMaterial = (t & 2) != 0;
    final bool hasFaceVertexUv = (t & 8) != 0;
    final bool hasFaceNormal = (t & 16) != 0;
    final bool hasFaceVertexNormal = (t & 32) != 0;
    final bool hasFaceColor = (t & 64) != 0;
    final bool hasFaceVertexColor = (t & 128) != 0;

    List<int> indices = [];
    for (int j = 0; j < d; j++) {
      indices.add(Faces[i++]);
    }

    int mat = 0;
    if (hasMaterial) {
      mat = Faces[i++];
    }

    List<VM.Vector2> uv = [];
    if (hasFaceVertexUv) {
      for (int j = 0; j < d; j++) {
        uv.add(Uvs[Faces[i++]]);
      }
    }

    List<VM.Vector3> normal = [];
    if (hasFaceNormal) {
      VM.Vector3 norm = Normals[Faces[i++]];
      for (int j = 0; j < d; j++) {
        normal.add(norm);
      }
    }

    if (hasFaceVertexNormal) {
      for (int j = 0; j < d; j++) {
        normal.add(Normals[Faces[i++]]);
      }
    }

    List<int> color = [];
    if (hasFaceColor) {
      assert(false);
      int col = Faces[i++];
      for (int j = 0; j < d; j++) {
        color.add(col);
      }
    }

    if (hasFaceVertexColor) {
      assert(false);
      for (int j = 0; j < d; j++) {
        color.add(Faces[i++]);
      }
    }

    while (out.length <= mat) {
      GeometryBuilder gb = GeometryBuilder();
      if (Normals.isNotEmpty) gb.EnableAttribute(aNormal);
      if (Uvs.isNotEmpty) gb.EnableAttribute(aTexUV);
      if (skinMultiplier > 0) {
        gb.EnableAttribute(aBoneIndex);
        gb.EnableAttribute(aBoneWeight);
      }
      out.add(gb);
    }
    GeometryBuilder gb = out[mat];
    List<VM.Vector3> vertex = [];

    for (int i in indices) {
      vertex.add(Vertices[i]);
    }

    if (d == 3) {
      gb.AddVerticesFace3(vertex);
    } else {
      assert(d == 4);
      gb.AddVerticesFace4(vertex);
    }
    if (uv.isNotEmpty) {
      gb.AddAttributesVector2(aTexUV, uv);
    }
    if (normal.isNotEmpty) {
      gb.AddAttributesVector3(aNormal, normal);
    }

    if (skinMultiplier > 0) {
      assert(Vertices.length == SkinIndex!.length);
      assert(Vertices.length == SkinWeight!.length);

      List<VM.Vector4> boneIndex = [];
      List<VM.Vector4> boneWeight = [];
      for (int i in indices) {
        boneIndex.add(SkinIndex![i]);
        boneWeight.add(SkinWeight![i]);
      }
      gb.AddAttributesVector4(aBoneIndex, boneIndex);
      gb.AddAttributesVector4(aBoneWeight, boneWeight);
    }
  }

  print("out: ${out.length} ${out[0]}");
  return out;
}

SkeletalAnimation ImportAnimationFromThreeJsJson(
  Map<String, Object?> json,
  List<Bone> skeleton,
) {
  final animation = _JsonMap(json["animation"]);
  final hierarchy = _JsonObjects(animation["hierarchy"]).toList();
  SkeletalAnimation s = SkeletalAnimation(
    animation["name"] as String,
    _JsonDouble(animation["length"]),
    hierarchy.length,
  );
  assert(hierarchy.length == _JsonList(json["bones"]).length);
  for (int i = 0; i < hierarchy.length; ++i) {
    List<double> pTimes = [];
    List<VM.Vector3> pValues = [];
    List<double> rTimes = [];
    List<VM.Quaternion> rValues = [];
    List<double> sTimes = [];
    List<VM.Vector3> sValues = [];
    for (final m in _JsonObjects(hierarchy[i]["keys"])) {
      double t = _JsonDouble(m["time"]);

      if (m.containsKey("pos")) {
        pTimes.add(t);
        pValues.add(MakeTransVector3(m["pos"] as List<Object?>?));
      }

      if (m.containsKey("scale")) {
        sTimes.add(t);
        sValues.add(MakeScaleVector3(m["scl"] as List<Object?>?));
      }

      if (m.containsKey("rot")) {
        rTimes.add(t);
        rValues.add(MakeQuaternion(m["rot"] as List<Object?>?));
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
    s.InsertBone(ba);
  }
  print("anim-bones: ${s.animList.length}");
  return s;
}

List<Bone> ImportSkeletonFromThreeJsJson(Map<String, Object?> json) {
  final metadata = _JsonMap(json["metadata"]);
  final Bones = _JsonObjects(json["bones"]).toList();
  assert(Bones.length == metadata["bones"]);
  List<Bone> out = List.generate(Bones.length, (i) {
    final m = Bones[i];
    String name = m["name"] as String;
    int parent = m["parent"] as int;
    final VM.Vector3 s = MakeScaleVector3(m["scl"] as List<Object?>?);
    final VM.Vector3 t = MakeTransVector3(m["pos"] as List<Object?>?);
    final VM.Quaternion r = MakeQuaternion(m["rotq"] as List<Object?>?);
    VM.Matrix4 mat = VM.Matrix4.zero()
      ..setFromTranslationRotationScale(t, r, s);
    if (i != 0 && parent < 0) {
      print("found unusal root node $i $parent");
    }
    return Bone(name, i, parent, mat, VM.Matrix4.identity());
  });
  print("bones: ${out.length}");
  RecomputeLocalOffsets(out);
  return out;
}
