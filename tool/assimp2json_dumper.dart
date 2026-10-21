//https://github.com/acgessler/assimp2json

import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:chronosgl/src/core/lib.dart';
import 'package:chronosgl/src/importer/lib.dart';
import 'package:chronosgl/src/animation/lib.dart';

void showInfo(Map<String, Object?> json) {
  for (String k in json.keys) {
    Object? val = json[k];
    if (val is Map<Object?, Object?>) {
      print("$k ${val.length}");
    } else if (val is List<Object?>) {
      print("$k ${val.length}");
    } else {
      print("$k $val");
    }
  }
}

void main(List<String> arguments) {
  final parser = ArgParser()..addFlag("faces", negatable: false, abbr: 'f');

  ArgResults argResults = parser.parse(arguments);
  List<String> paths = argResults.rest;
  for (var p in paths) {
    print("reading  $p");

    print("reading mesh from: $p");
    String meshData = File(p).readAsStringSync();
    final jsonData = json.decode(meshData) as Map<String, Object?>;

    List<Bone> skeleton = importSkeletonFromAssimp2Json(jsonData);

    print("Bones: ${skeleton.length}");
    GeometryBuilder gb = importGeometryFromAssimp2JsonMesh(
      (jsonData["meshes"] as List<Object?>)[0] as Map<String, Object?>,
      skeleton,
    );
    print(gb);

    SkeletalAnimation anim = importAnimationFromAssimp2Json(
      (jsonData["animations"] as List<Object?>)[0] as Map<String, Object?>,
      skeleton,
    );
    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    print(">>>>>>>>>> Bones");
    print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    for (Bone b in skeleton) {
      print(b);
    }

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
