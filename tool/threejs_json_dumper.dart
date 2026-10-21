// cf.: https://github.com/mrdoob/three.js/blob/dev/src/loaders/JSONLoader.js
//      https://github.com/mrdoob/three.js/wiki/JSON-Model-format-3

import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/src/core/lib.dart';
import 'package:chronosgl/src/importer/lib.dart';
import 'package:chronosgl/src/animation/lib.dart';

// Note this is similar to lib/src/importer/threejs.dart
void dumpFaces(Map<String, Object?> json, bool verbose) {
  final faces = (json["faces"] as List<Object?>).cast<int>();
  int i = 0;
  int count = 0;

  int mVertex = 9;
  int mUv = 0;
  int mNormal = 0;
  int mMat = 0;

  while (i < faces.length) {
    count++;
    final int t = faces[i++];
    final int d = (t & 1) == 0 ? 3 : 4; // quad or triangle
    final bool hasMaterial = (t & 2) != 0;
    final bool hasFaceVertexUv = (t & 8) != 0;
    final bool hasFaceNormal = (t & 16) != 0;
    final bool hasFaceVertexNormal = (t & 32) != 0;
    final bool hasFaceColor = (t & 64) != 0;
    final bool hasFaceVertexColor = (t & 128) != 0;
    List<String> tokens = [];
    tokens.add(t.toString());

    tokens.add("  v: ");
    for (int j = 0; j < d; j++) {
      int x = faces[i++];
      if (x > mVertex) mVertex = x;
      tokens.add(x.toString());
      tokens.add(" ");
    }

    if (hasMaterial) {
      tokens.add("  m: ");
      int x = faces[i++];
      if (x > mMat) mMat = x;
      tokens.add(x.toString());
      tokens.add(" ");
    }

    if (hasFaceVertexUv) {
      tokens.add("  uv: ");
      for (int j = 0; j < d; j++) {
        int x = faces[i++];
        if (x > mUv) mUv = x;
        tokens.add(x.toString());
        tokens.add(" ");
      }
    }

    if (hasFaceNormal) {
      tokens.add("  fn: ");
      int x = faces[i++];
      if (x > mNormal) mNormal = x;
      tokens.add(x.toString());
      tokens.add(" ");
    }

    if (hasFaceVertexNormal) {
      tokens.add("  n: ");
      for (int j = 0; j < d; j++) {
        int x = faces[i++];
        if (x > mNormal) mNormal = x;
        tokens.add(x.toString());
        tokens.add(" ");
      }
    }

    if (hasFaceColor) {
      tokens.add("  fc: ");
      int x = faces[i++];
      tokens.add(x.toString());
      tokens.add(" ");
    }

    if (hasFaceVertexColor) {
      tokens.add("  c: ");
      for (int j = 0; j < d; j++) {
        int x = faces[i++];
        tokens.add(x.toString());
        tokens.add(" ");
      }
    }
    if (verbose) {
      print(tokens.join(""));
    }
  }

  print("processed faces: $count");
  print("max Material: $mMat");
  print("max Vertex: $mVertex");
  print("max UV: $mUv");
  print("max Normal: $mNormal");
}

void showInfo(Map<String, Object?> json) {
  final materials = json["materials"] as List<Object?>;
  final vertices = json["vertices"] as List<Object?>;
  final normals = json["normals"] as List<Object?>;
  final colors = json["colors"] as List<Object?>;
  List<Object?> uvs = [];
  final uvLayers = json["uvs"] as List<Object?>;
  assert(uvLayers.length <= 1);
  if (uvLayers.length == 1) {
    uvs = uvLayers[0] as List<Object?>;
  }
  final faces = json["faces"] as List<Object?>;
  final bones = json["bones"] as List<Object?>;
  final morphTargets = (json["morphTargets"] as List<Object?>? ?? [])
      .cast<Map<String, Object?>>();

  final skinIndices = json["skinIndices"] as List<Object?>;
  final skinWeights = json["skinWeights"] as List<Object?>;
  final animation = json["animation"] as Map<String, Object?>;
  final metadata = json["metadata"];

  print("meta: $metadata");
  print("materials: ${materials.length}");
  print("vertices: ${vertices.length}  ${vertices.length ~/ 3}");
  print("normals: ${normals.length} ${normals.length ~/ 3}");
  print("colors: ${colors.length}");
  print("uvs: ${uvs.length}  ${uvs.length ~/ 2}");
  print("faces: ${faces.length} ${faces.length ~/ 3}");
  print("bones: ${bones.length}");
  print("skinIndices: ${skinIndices.length} ${skinIndices.length ~/ 2}");
  print("skinWeigths: ${skinWeights.length}");
  print("animation: ${animation['name']}");
  for (final m in morphTargets) {
    print(
      "morphTarget: ${m['name']} ${(m['vertices'] as List<Object?>).length}",
    );
  }
}

void main(List<String> arguments) {
  final parser = ArgParser()..addFlag("faces", negatable: false, abbr: 'f');

  ArgResults argResults = parser.parse(arguments);
  List<String> paths = argResults.rest;
  for (var p in paths) {
    print("reading  $p");

    print("reading mesh from: $p");
    var meshData = File(p).readAsStringSync();
    final jsonData = json.decode(meshData) as Map<String, Object?>;
    showInfo(jsonData);
    dumpFaces(jsonData, argResults['faces'] as bool);

    List<GeometryBuilder> gb = importGeometryFromThreeJsJson(jsonData);
    print(gb);
    List<Bone> skeleton = importSkeletonFromThreeJsJson(jsonData);

    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    print(">>>>>>>>>> Bones");
    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    for (Bone b in skeleton) {
      print(b);
    }
    SkeletalAnimation anim = importAnimationFromThreeJsJson(jsonData, skeleton);

    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    print(">>>>>>>>>> BoneAnims");
    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    for (BoneAnimation? ba in anim.animList) {
      print(ba);
    }

    vm.Matrix4 globalOffsetTransform = vm.Matrix4.identity();

    AnimatedSkeleton animatedSkeleton = AnimatedSkeleton(skeleton.length);
    updateAnimatedSkeleton(
      skeleton,
      globalOffsetTransform,
      anim,
      animatedSkeleton,
      0.0,
    );

    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    print(">>>>>>>>>> Animated");
    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    for (int i = 0; i < skeleton.length; i++) {
      print(skeleton[i].boneName);
      print("global");
      print(animatedSkeleton.globalTransforms[i]);
      print("skinning");
      print(animatedSkeleton.skinningTransforms[i]);
    }
  }
  return;
}
