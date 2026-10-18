@TestOn('chrome')
library;

// These tests exercise the engine's existing browser backend.
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:web_gl' as webgl;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

Future<Map<String, Object?>> _loadAsset(String name) async {
  final channel = spawnHybridUri('support/importer_asset.dart', message: name);
  final text = await channel.stream.first as String;
  return jsonDecode(text) as Map<String, Object?>;
}

void _checkAnimatedPose(List<Bone> skeleton, SkeletalAnimation animation) {
  expect(skeleton, isNotEmpty);
  expect(animation.animList.whereType<BoneAnimation>(), isNotEmpty);
  final posed = AnimatedSkeleton(skeleton.length);
  UpdateAnimatedSkeleton(
    skeleton,
    vm.Matrix4.identity(),
    animation,
    posed,
    0.0,
  );
  final initial = posed.skinningTransforms
      .expand((matrix) => matrix.storage)
      .toList();
  UpdateAnimatedSkeleton(
    skeleton,
    vm.Matrix4.identity(),
    animation,
    posed,
    0.25,
  );
  final moved = posed.skinningTransforms
      .expand((matrix) => matrix.storage)
      .toList();
  expect(moved.every((value) => value.isFinite), isTrue);
  expect(
    moved,
    isNot(orderedEquals(initial)),
    reason: 'The model must animate, not just decode without errors',
  );
}

void main() {
  test(
    'Assimp monster imports geometry, skin weights, and animation',
    () async {
      final json = await _loadAsset('assimp');
      final mesh =
          (json['meshes'] as List<Object?>).first as Map<String, Object?>;
      final skeleton = ImportSkeletonFromAssimp2Json(json);
      final geometry = ImportGeometryFromAssimp2JsonMesh(mesh, skeleton);
      expect(
        geometry.vertices.length,
        (mesh['vertices'] as List<Object?>).length ~/ 3,
      );
      expect(geometry.faces3.length, (mesh['faces'] as List<Object?>).length);
      final weights = geometry.attributes[aBoneWeight]! as List<vm.Vector4>;
      expect(weights.length, geometry.vertices.length);
      expect(
        weights.any((weight) => weight.x + weight.y + weight.z + weight.w > 0),
        isTrue,
      );
      final animation = ImportAnimationFromAssimp2Json(
        (json['animations'] as List<Object?>).first as Map<String, Object?>,
        skeleton,
      );
      _checkAnimatedPose(skeleton, animation);
    },
  );

  test('ThreeJS knight imports faces, skeleton, and animated poses', () async {
    final json = await _loadAsset('threejs');
    final geometries = ImportGeometryFromThreeJsJson(json);
    expect(geometries, isNotEmpty);
    expect(geometries.expand((geometry) => geometry.vertices), isNotEmpty);
    expect(
      geometries.any(
        (geometry) => geometry.faces3.isNotEmpty || geometry.faces4.isNotEmpty,
      ),
      isTrue,
    );
    final skeleton = ImportSkeletonFromThreeJsJson(json);
    final animation = ImportAnimationFromThreeJsJson(json, skeleton);
    _checkAnimatedPose(skeleton, animation);
  });

  test('WebGL buffer readback respects the destination typed-data view', () {
    final cgl = ChronosGL(
      html.CanvasElement(width: 16, height: 16),
      antialiasing: false,
    );
    final buffer = cgl.createBuffer();
    addTearDown(() {
      cgl.deleteBuffer(buffer);
      (cgl.getExtension('WEBGL_lose_context') as webgl.LoseContext?)
          ?.loseContext();
    });
    final input = Float32List.fromList([0.25, -0.5, 12.0, 42.0]);
    cgl.ChangeArrayBuffer(buffer, input);
    final storage = Float32List.fromList([-999, 0, 0, 0, 0, -999]);
    final view = Float32List.view(
      storage.buffer,
      Float32List.bytesPerElement,
      4,
    );
    cgl.GetArrayBuffer(buffer, view);
    expect(storage, [-999, 0.25, -0.5, 12.0, 42.0, -999]);
    view.fillRange(0, view.length, 0.0);
    cgl.GetTransformBuffer(buffer, view);
    expect(storage, [-999, 0.25, -0.5, 12.0, 42.0, -999]);
    expect(cgl.getError(), GL_NO_ERROR);
  });

  test('Typed texture uploads and partial updates preserve RGBA pixels', () {
    final cgl = ChronosGL(
      html.CanvasElement(width: 16, height: 16),
      antialiasing: false,
    );
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as webgl.LoseContext?)
          ?.loseContext();
    });
    final original = Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      0,
      255,
      255,
      255,
      255,
      255,
      255,
    ]);
    final texture = TypedTextureMutable(
      cgl,
      'rgba',
      2,
      2,
      GL_RGBA8,
      TexturePropertiesFramebuffer,
      GL_RGBA,
      GL_UNSIGNED_BYTE,
      original,
    );
    final framebuffer = Framebuffer(cgl, texture);
    expect(framebuffer.ExtractByteData(null, 0, 0, 2, 2), original);
    final updated = Uint8List.fromList([
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      255,
    ]);
    texture.UpdateContent(updated, GL_RGBA, GL_UNSIGNED_BYTE);
    expect(framebuffer.ExtractByteData(null, 0, 0, 2, 2), updated);
    texture.UpdateContentPartial(
      Uint8List.fromList([0, 0, 255, 255]),
      GL_RGBA,
      GL_UNSIGNED_BYTE,
      1,
      0,
      1,
      1,
    );
    updated.setRange(4, 8, [0, 0, 255, 255]);
    expect(framebuffer.ExtractByteData(null, 0, 0, 2, 2), updated);
    expect(cgl.getError(), GL_NO_ERROR);
  });
}
