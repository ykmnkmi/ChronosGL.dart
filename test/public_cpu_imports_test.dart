@TestOn('vm')
library;

import 'package:chronosgl/animation.dart';
import 'package:chronosgl/camera.dart';
import 'package:chronosgl/core.dart';
import 'package:chronosgl/geometry.dart';
import 'package:chronosgl/importers.dart';
import 'package:chronosgl/shaders.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  test('public CPU modules compose without browser dependencies', () {
    final geometry = importGeometryFromWavefront('''
v 0 0 0
v 1 0 0
v 0 1 0
f 1 2 3
''')..validate();
    expect(geometry.vertices, hasLength(3));
    expect(cubeGeometry()..validate(), isA<GeometryBuilder>());

    final transform = Transform()..setPosition(0, 0, -3);
    final camera = PerspectiveCamera(near: 0.1, far: 100);
    final origin = camera.viewProjectionMatrix.transformed3(
      transform.matrix.getTranslation(),
    );
    expect(origin.x, closeTo(0, 1e-6));
    expect(origin.y, closeTo(0, 1e-6));
    expect(colorWhite.toVector3(), vm.Vector3.all(1));

    final skeleton = AnimatedSkeleton(1);
    expect(skeleton.globalTransforms, hasLength(1));
    final vertex = ShaderObject.create(
      name: 'no-attributes',
      stage: ShaderStage.vertex,
    )..setBodyWithMain(['gl_Position = vec4(0.0, 0.0, 0.0, 1.0);']);
    expect(vertex.stage, ShaderStage.vertex);
    expect(vertex.shader, isNot(contains('out vec4 $oFragColor')));
    expect(solidColorFragmentShader.stage, ShaderStage.fragment);
    expect(retrieveShaderVarDesc(aPosition).type, varTypeVec3);
  });
}
