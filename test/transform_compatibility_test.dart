@TestOn('chrome')
library;

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/core.dart' as math_core;
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  test('public aggregate and math entry point export the same Transform', () {
    final Transform transform = math_core.Transform()..setPosition(1, 2, 3);
    expect(transform.matrix.getTranslation().storage, orderedEquals([1, 2, 3]));
  });

  test('explicit matrix copy bridges Transform to a legacy Node', () {
    final transform = Transform()
      ..setPosition(1, 2, 3)
      ..setScale(2, 3, 4);
    final node = Node.container('legacy');
    transform.copyMatrixInto(node.transform);
    final parent = vm.Matrix4.translationValues(10, 20, 30);
    final world = node.updateModelMatrix(parent);
    expect(
      world.transformed3(vm.Vector3(1, 1, 1)).storage,
      orderedEquals([13, 25, 37]),
    );
    expect(parent.getTranslation().storage, orderedEquals([10, 20, 30]));
    transform.translate(4, 0, 0);
    expect(node.getPos().storage, orderedEquals([1, 2, 3]));
    transform.copyMatrixInto(node.transform);
    expect(node.getPos().storage, orderedEquals([5, 2, 3]));
    node.setPos(7, 8, 9);
    expect(transform.position.storage, orderedEquals([5, 2, 3]));
  });
}
