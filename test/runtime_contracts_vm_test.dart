import 'package:chronosgl/animation.dart';
import 'package:chronosgl/geometry.dart';
import 'package:chronosgl/importers.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

Bone _bone(int index, int parent) => Bone.named(
  name: 'bone-$index',
  index: index,
  parentIndex: parent,
  localTransform: vm.Matrix4.identity(),
  offsetTransform: vm.Matrix4.identity(),
);

void main() {
  test('geometry mutations reject invalid arguments before changing data', () {
    final point = GeometryBuilder(true)..addVertex(vm.Vector3.zero());
    expect(() => point.addFace3(0, 0, 0), throwsStateError);
    expect(point.faces3, isEmpty);
    final surface = GeometryBuilder();
    expect(
      () => surface.addVerticesFace3([vm.Vector3.zero()]),
      throwsArgumentError,
    );
    expect(surface.vertices, isEmpty);
    expect(surface.faces3, isEmpty);
    surface.enableAttribute(aNormal);
    surface.addVertex(vm.Vector3(1, 2, 3));
    surface.addAttributeVector3(aNormal, vm.Vector3(0, 0, 1));
    expect(
      () => surface.applyTransform(vm.Matrix4.identity()),
      throwsArgumentError,
    );
    expect(surface.vertices.single, vm.Vector3(1, 2, 3));
  });

  test(
    'grid generation checks dimensions and vertex counts before mutation',
    () {
      final geometry = GeometryBuilder()..addVertex(vm.Vector3.zero());
      expect(() => geometry.generateRegularGridUV(1, 1), throwsArgumentError);
      expect(
        () => geometry.generateRegularGridFaces(2, 2, false),
        throwsStateError,
      );
      expect(geometry.attributes, isEmpty);
      expect(geometry.faces4, isEmpty);
    },
  );

  test(
    'shape and contour contracts throw typed errors in every build mode',
    () {
      expect(() => cylinderGeometry(1, 1, 1, 2, true), throwsArgumentError);
      expect(() => torusKnotGeometry(wrap: true), throwsArgumentError);
      expect(() => torusKnotGeometry(segmentsR: 0), throwsArgumentError);
      expect(() => contourCircle(2, 1), throwsArgumentError);
      expect(() => triangulate([vm.Vector2.zero()]), throwsArgumentError);
      expect(() => isConvex([]), throwsArgumentError);
      expect(
        () => getContourGradient([
          vm.Vector2.zero(),
          vm.Vector2(1, 0),
          vm.Vector2(2, 0),
        ]),
        throwsArgumentError,
      );
      expect(() => bevelSupportPoints(1, 1, 1), throwsArgumentError);
      expect(
        () => mapStringToEasing['custom'] = easingLinear,
        throwsUnsupportedError,
      );
      final cone = coneGeometryWireframeFriendly(
        radius: 1,
        height: 2,
        radialSubdivisions: 8,
      )..generateNormalsAssumingTriangleMode();
      cone.validate();
    },
  );

  test('importer vector widths are validated through VM public import', () {
    expect(() => convertToVector3List([1, 2]), throwsArgumentError);
    expect(() => convertToVector2List([1, 2, 3]), throwsArgumentError);
    expect(() => convertToVector4List(0, []), throwsArgumentError);
    expect(() => convertToVector4List(5, [1, 2, 3, 4, 5]), throwsArgumentError);
    final triangle = importGeometryFromWavefront(
      'v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n',
    );
    triangle.validate();
    expect(triangle.faces3, hasLength(1));
  });

  test('bone topology and animation insertion preserve track invariants', () {
    expect(() => _bone(-1, -1), throwsArgumentError);
    expect(() => _bone(1, 1), throwsArgumentError);
    final track = BoneAnimation.keyframes(bone: _bone(0, -1));
    final animation = SkeletalAnimation.named(
      name: 'idle',
      duration: 1,
      boneCount: 1,
    );
    final slots = animation.animList;
    expect(() => slots.add(track), throwsUnsupportedError);
    expect(() => slots[0] = track, throwsUnsupportedError);
    animation.insertBone(track);
    expect(slots.single, same(track));
    expect(() => animation.insertBone(track), throwsStateError);
    expect(
      () => animation.insertBone(BoneAnimation.keyframes(bone: _bone(1, 0))),
      throwsArgumentError,
    );
  });

  test('animation keyframes copy caller lists and reject malformed tracks', () {
    final bone = _bone(0, -1);
    final times = [0.0, 1.0];
    final positions = [vm.Vector3(2, 3, 4), vm.Vector3(5, 6, 7)];
    final track = BoneAnimation.keyframes(
      bone: bone,
      positionTimes: times,
      positions: positions,
    );
    times.clear();
    positions.first.setZero();
    positions.clear();
    final matrix = vm.Matrix4.zero();
    track.setBoneMatrixAtTick(0.5, matrix);
    expect(matrix.getTranslation(), vm.Vector3(2, 3, 4));
    expect(
      () => track.setBoneMatrixAtTick(double.nan, matrix),
      throwsArgumentError,
    );
    expect(
      () => BoneAnimation.keyframes(
        bone: bone,
        positionTimes: [0, 1],
        positions: [vm.Vector3.zero()],
      ),
      throwsArgumentError,
    );
    expect(
      () => BoneAnimation.keyframes(
        bone: bone,
        positionTimes: [1, 0],
        positions: [vm.Vector3.zero(), vm.Vector3.zero()],
      ),
      throwsArgumentError,
    );
    final posed = AnimatedSkeleton(1);
    expect(() => posed.globalTransforms.clear(), throwsUnsupportedError);
    expect(() => posed.skinningTransforms.clear(), throwsUnsupportedError);
  });
}
