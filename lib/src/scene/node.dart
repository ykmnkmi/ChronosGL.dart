part of 'lib.dart';

/// represents a hierarchy of objects that well be rendered
/// by rendered RenderProgram.
/// Typically that hierarchy is a tree but DAGs are supported.
/// Only leaf Nodes will cause draw calls by providing
/// MeshData and Material.
/// Non leaf Nodes are just containers for other Nodes
/// Each Node is a Spatial so it be re-oriented with respect to its parent
class Node extends Spatial {
  Node.container(super.name, [Node? child]) {
    if (child != null) children.add(child);
  }

  Node(super.name, this._meshData, this._material) {
    //if (!meshData.isOptimized) meshData.optimize();
  }

  Material? _material;
  MeshData? _meshData;

  // children inherent the parent matrix for its rotation and position
  final List<Node> children = [];
  final vm.Matrix3 _normMatrix = vm.Matrix3.zero();
  final vm.Matrix4 _modelMatrix = vm.Matrix4.identity();

  Material get material => _material!;

  MeshData get meshData => _meshData!;

  set meshData(MeshData md) {
    _meshData = md;
  }

  void add(Node node) {
    children.add(node);
  }

  void updateTransforms(UniformGroup transforms) {
    // TODO: computing the normal matrix like this is wrong
    _normMatrix.copyNormalMatrix(_modelMatrix);
    transforms.forceUniform(uTransformationMatrix, transform);
    transforms.forceUniform(uModelMatrix, _modelMatrix);
    transforms.forceUniform(uNormalMatrix, _normMatrix);
  }

  vm.Matrix4 updateModelMatrix(vm.Matrix4 parent) {
    // copy the mvMatrix, so we don't change the original
    _modelMatrix.setFrom(parent);
    _modelMatrix.multiply(transform);
    return _modelMatrix;
  }

  bool somethingToDraw() {
    return _material != null && _meshData != null;
  }

  @override
  String toString() => "NODE[$name]";
}
