// Importer for assimp2json generated files
// https://github.com/acgessler/assimp2json
// Online converter: http://www.greentoken.de/onlineconv/
part of 'lib.dart';

List<double> _Floatify(List<Object?> lst) => lst.map(_JsonDouble).toList();

List<int> _Intify(List<Object?> lst) {
  List<int> out = List.generate(lst.length, (i) => (lst[i] as num).toInt());
  return out;
}

List<List<int>> _ListIntify(List<Object?> lst) {
  List<List<int>> out = List.generate(
    lst.length,
    (i) => _Intify(_JsonList(lst[i])),
  );
  return out;
}

//Also fills in the offsets for skeleton
GeometryBuilder ImportGeometryFromAssimp2JsonMesh(
  Map<String, Object?> mesh,
  List<Bone> skeleton,
) {
  GeometryBuilder gb = GeometryBuilder();
  String name = mesh['name'] as String;

  assert(mesh.containsKey("vertices"), "no vertices");
  gb.AddVertices(ConvertToVector3List(_JsonList(mesh['vertices'])));
  if (mesh.containsKey("normals")) {
    gb.EnableAttribute(aNormal);
    gb.AddAttributesVector3(
      aNormal,
      ConvertToVector3List(_JsonList(mesh['normals'])),
    );
  }
  if (mesh.containsKey("texturecoords")) {
    assert(_JsonList(mesh["texturecoords"]).length == 1);
    gb.EnableAttribute(aTexUV);
    gb.AddAttributesVector2(
      aTexUV,
      ConvertToVector2List(_JsonList(_JsonList(mesh['texturecoords'])[0])),
    );
  }
  if (mesh.containsKey("tangents")) {
    gb.EnableAttribute(aTangent);
    gb.AddAttributesVector3(
      aTangent,
      ConvertToVector3List(_JsonList(mesh['tangents'])),
    );
  }
  if (mesh.containsKey("bitangents")) {
    gb.EnableAttribute(aBitangent);
    gb.AddAttributesVector3(
      aBitangent,
      ConvertToVector3List(_JsonList(mesh['bitangents'])),
    );
  }
  List<List<int>> faces = _ListIntify(_JsonList(mesh['faces']));
  for (List<int> f in faces) {
    assert(f.length == 3);
    gb.AddFace3(f[0], f[1], f[2]);
  }

  Map<String, Bone> name2bone = <String, Bone>{};
  for (var b in skeleton) {
    name2bone[b.boneName] = b;
  }
  final int n = _JsonList(mesh['normals']).length ~/ 3;
  List<VM.Vector4> indices = List.generate(n, (i) => VM.Vector4.zero());
  List<VM.Vector4> weights = List.generate(n, (i) => VM.Vector4.zero());
  for (final b in _JsonObjects(mesh["bones"])) {
    assert(name2bone.containsKey(b["name"]));
    final Bone bone = name2bone[b["name"]] as Bone;
    // Note: Surprising side-effect
    bone.offsetTransform.copyFromArray(_Floatify(_JsonList(b["offsetmatrix"])));
    bone.offsetTransform.transpose();
    if (b.containsKey("weights")) {
      final double boneIndex = bone.boneIndex.toDouble();

      for (final w in _JsonLists(b["weights"])) {
        final int vertex = w[0] as int;
        int pos;
        for (pos = 0; pos < 4; ++pos) {
          if (weights[vertex][pos] == 0.0) break;
        }
        assert(pos != 4);
        weights[vertex][pos] = _JsonDouble(w[1]);
        indices[vertex][pos] = boneIndex;
      }
    }
  }
  gb.EnableAttribute(aBoneIndex);
  gb.EnableAttribute(aBoneWeight);
  gb.AddAttributesVector4(aBoneIndex, indices);
  gb.AddAttributesVector4(aBoneWeight, weights);

  print("mesh $name $gb ${mesh.keys}");
  return gb;
}

List<Bone> ImportSkeletonFromAssimp2Json(Map<String, Object?> json) {
  List<Bone> out = <Bone>[];
  int count = 0;

  void dfs(Map<String, Object?> node, int parent) {
    final String name = node["name"] as String;

    final VM.Matrix4 transform = VM.Matrix4.fromList(
      _Floatify(_JsonList(node["transformation"])),
    );
    transform.transpose();

    final VM.Matrix4 offset = VM.Matrix4.identity();
    Bone bone = Bone(name, count, parent, transform, offset);
    count++;
    out.add(bone);
    if (node.containsKey("children")) {
      for (final child in _JsonObjects(node["children"])) {
        dfs(child, bone.boneIndex);
      }
    }
  }

  // We do not represent the root node as a node as it seems to have
  // a bad transform matrix
  // dfs(json["rootnode"], -1);
  final root = _JsonMap(json["rootnode"]);
  for (final child in _JsonObjects(root["children"])) {
    dfs(child, -1);
  }

  return out;
}

SkeletalAnimation ImportAnimationFromAssimp2Json(
  Map<String, Object?> json,
  List<Bone> skeleton,
) {
  Map<String, Bone> name2bone = <String, Bone>{};
  for (var b in skeleton) {
    name2bone[b.boneName] = b;
  }

  String name = json["name"] as String;
  double tickspersecond = _JsonDouble(json["tickspersecond"]);
  double duration = _JsonDouble(json["duration"]);
  final channels = _JsonObjects(json["channels"]);
  SkeletalAnimation anim = SkeletalAnimation(name, duration, skeleton.length);
  print("animated bones: ${channels.length}");
  for (final c in channels) {
    assert(name2bone.containsKey(c["name"]));
    final Bone bone = name2bone[c["name"]] as Bone;

    List<double> positionTimes = [];
    List<VM.Vector3> positionValues = [];
    for (final pos in _JsonLists(c["positionkeys"])) {
      positionTimes.add(_JsonDouble(pos[0]) / tickspersecond);
      positionValues.add(MakeVector3(_JsonList(pos[1])));
    }

    List<double> rotationTimes = [];
    List<VM.Quaternion> rotationValues = [];
    for (final rot in _JsonLists(c["rotationkeys"])) {
      rotationTimes.add(_JsonDouble(rot[0]) / tickspersecond);
      List<double> q = _Floatify(_JsonList(rot[1]));
      rotationValues.add(VM.Quaternion(q[1], q[2], q[3], q[0]));
    }

    List<double> scaleTimes = [];
    List<VM.Vector3> scaleValues = [];
    for (final sca in _JsonLists(c["scalingkeys"])) {
      scaleTimes.add(_JsonDouble(sca[0]) / tickspersecond);
      scaleValues.add(MakeVector3(_JsonList(sca[1])));
    }

    anim.InsertBone(
      BoneAnimation(
        bone,
        positionTimes,
        positionValues,
        rotationTimes,
        rotationValues,
        scaleTimes,
        scaleValues,
      ),
    );
  }

  return anim;
}
