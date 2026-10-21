// Importer for assimp2json generated files
// https://github.com/acgessler/assimp2json
// Online converter: http://www.greentoken.de/onlineconv/
part of 'lib.dart';

List<double> _floatify(List<Object?> lst) => lst.map(_jsonDouble).toList();

List<int> _intify(List<Object?> lst) {
  List<int> out = List.generate(lst.length, (i) => (lst[i] as num).toInt());
  return out;
}

List<List<int>> _listIntify(List<Object?> lst) {
  List<List<int>> out = List.generate(
    lst.length,
    (i) => _intify(_jsonList(lst[i])),
  );
  return out;
}

//Also fills in the offsets for skeleton
GeometryBuilder importGeometryFromAssimp2JsonMesh(
  Map<String, Object?> mesh,
  List<Bone> skeleton,
) {
  GeometryBuilder gb = GeometryBuilder();
  String name = mesh['name'] as String;

  assert(mesh.containsKey("vertices"), "no vertices");
  gb.addVertices(convertToVector3List(_jsonList(mesh['vertices'])));
  if (mesh.containsKey("normals")) {
    gb.enableAttribute(aNormal);
    gb.addAttributesVector3(
      aNormal,
      convertToVector3List(_jsonList(mesh['normals'])),
    );
  }
  if (mesh.containsKey("texturecoords")) {
    assert(_jsonList(mesh["texturecoords"]).length == 1);
    gb.enableAttribute(aTexUV);
    gb.addAttributesVector2(
      aTexUV,
      convertToVector2List(_jsonList(_jsonList(mesh['texturecoords'])[0])),
    );
  }
  if (mesh.containsKey("tangents")) {
    gb.enableAttribute(aTangent);
    gb.addAttributesVector3(
      aTangent,
      convertToVector3List(_jsonList(mesh['tangents'])),
    );
  }
  if (mesh.containsKey("bitangents")) {
    gb.enableAttribute(aBitangent);
    gb.addAttributesVector3(
      aBitangent,
      convertToVector3List(_jsonList(mesh['bitangents'])),
    );
  }
  List<List<int>> faces = _listIntify(_jsonList(mesh['faces']));
  for (List<int> f in faces) {
    assert(f.length == 3);
    gb.addFace3(f[0], f[1], f[2]);
  }

  Map<String, Bone> name2bone = <String, Bone>{};
  for (var b in skeleton) {
    name2bone[b.boneName] = b;
  }
  final int n = _jsonList(mesh['normals']).length ~/ 3;
  List<vm.Vector4> indices = List.generate(n, (i) => vm.Vector4.zero());
  List<vm.Vector4> weights = List.generate(n, (i) => vm.Vector4.zero());
  for (final b in _jsonObjects(mesh["bones"])) {
    assert(name2bone.containsKey(b["name"]));
    final Bone bone = name2bone[b["name"]] as Bone;
    // Note: Surprising side-effect
    bone.offsetTransform.copyFromArray(_floatify(_jsonList(b["offsetmatrix"])));
    bone.offsetTransform.transpose();
    if (b.containsKey("weights")) {
      final double boneIndex = bone.boneIndex.toDouble();

      for (final w in _jsonLists(b["weights"])) {
        final int vertex = w[0] as int;
        int pos;
        for (pos = 0; pos < 4; ++pos) {
          if (weights[vertex][pos] == 0.0) break;
        }
        assert(pos != 4);
        weights[vertex][pos] = _jsonDouble(w[1]);
        indices[vertex][pos] = boneIndex;
      }
    }
  }
  gb.enableAttribute(aBoneIndex);
  gb.enableAttribute(aBoneWeight);
  gb.addAttributesVector4(aBoneIndex, indices);
  gb.addAttributesVector4(aBoneWeight, weights);

  print("mesh $name $gb ${mesh.keys}");
  return gb;
}

List<Bone> importSkeletonFromAssimp2Json(Map<String, Object?> json) {
  List<Bone> out = <Bone>[];
  int count = 0;

  void dfs(Map<String, Object?> node, int parent) {
    final String name = node["name"] as String;

    final vm.Matrix4 transform = vm.Matrix4.fromList(
      _floatify(_jsonList(node["transformation"])),
    );
    transform.transpose();

    final vm.Matrix4 offset = vm.Matrix4.identity();
    Bone bone = Bone(name, count, parent, transform, offset);
    count++;
    out.add(bone);
    if (node.containsKey("children")) {
      for (final child in _jsonObjects(node["children"])) {
        dfs(child, bone.boneIndex);
      }
    }
  }

  // We do not represent the root node as a node as it seems to have
  // a bad transform matrix
  // dfs(json["rootnode"], -1);
  final root = _jsonMap(json["rootnode"]);
  for (final child in _jsonObjects(root["children"])) {
    dfs(child, -1);
  }

  return out;
}

SkeletalAnimation importAnimationFromAssimp2Json(
  Map<String, Object?> json,
  List<Bone> skeleton,
) {
  Map<String, Bone> name2bone = <String, Bone>{};
  for (var b in skeleton) {
    name2bone[b.boneName] = b;
  }

  String name = json["name"] as String;
  double tickspersecond = _jsonDouble(json["tickspersecond"]);
  double duration = _jsonDouble(json["duration"]);
  final channels = _jsonObjects(json["channels"]);
  SkeletalAnimation anim = SkeletalAnimation(name, duration, skeleton.length);
  print("animated bones: ${channels.length}");
  for (final c in channels) {
    assert(name2bone.containsKey(c["name"]));
    final Bone bone = name2bone[c["name"]] as Bone;

    List<double> positionTimes = [];
    List<vm.Vector3> positionValues = [];
    for (final pos in _jsonLists(c["positionkeys"])) {
      positionTimes.add(_jsonDouble(pos[0]) / tickspersecond);
      positionValues.add(makeVector3(_jsonList(pos[1])));
    }

    List<double> rotationTimes = [];
    List<vm.Quaternion> rotationValues = [];
    for (final rot in _jsonLists(c["rotationkeys"])) {
      rotationTimes.add(_jsonDouble(rot[0]) / tickspersecond);
      List<double> q = _floatify(_jsonList(rot[1]));
      rotationValues.add(vm.Quaternion(q[1], q[2], q[3], q[0]));
    }

    List<double> scaleTimes = [];
    List<vm.Vector3> scaleValues = [];
    for (final sca in _jsonLists(c["scalingkeys"])) {
      scaleTimes.add(_jsonDouble(sca[0]) / tickspersecond);
      scaleValues.add(makeVector3(_jsonList(sca[1])));
    }

    anim.insertBone(
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
