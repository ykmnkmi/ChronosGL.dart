part of 'lib.dart';

/// A local transform and ordered child links in a scene graph.
///
/// A node may be shared by multiple parents. Its world transform belongs to a
/// traversal path, rather than to the node. Only [MeshNode] provides drawable
/// resources; [GroupNode] is a container without mesh or material properties.
abstract class Node extends Spatial {
  Node._(super.name);

  @Deprecated('Use GroupNode instead.')
  factory Node.container(String name, [Node? child]) = GroupNode;

  @Deprecated('Use MeshNode instead.')
  factory Node(String name, GpuMesh mesh, Material material) = MeshNode;

  /// Owned child links in insertion order. Nodes and their resources are borrowed.
  /// Change links between draws, rather than during traversal.
  final List<Node> children = [];
  final vm.Matrix4 _modelMatrix = vm.Matrix4.identity();

  void add(Node node) {
    children.add(node);
  }

  /// Writes independent local, world and inverse-transpose normal matrices.
  ///
  /// Without [modelMatrix], uses the last explicit [updateModelMatrix] result.
  /// Traversal supplies its own path-specific world matrix.
  void updateTransforms(UniformGroup transforms, [vm.Matrix4? modelMatrix]) {
    final model = vm.Matrix4.copy(modelMatrix ?? _modelMatrix);
    final normal = vm.Matrix3.zero()..copyNormalMatrix(model);
    transforms.forceUniform(uTransformationMatrix, vm.Matrix4.copy(transform));
    transforms.forceUniform(uModelMatrix, model);
    transforms.forceUniform(uNormalMatrix, normal);
  }

  /// Computes `parent * local`, without changing [parent].
  ///
  /// The returned matrix is an independent value. The node remembers a copy
  /// for legacy [updateTransforms] calls, but traversal never relies on it.
  vm.Matrix4 updateModelMatrix(vm.Matrix4 parent) {
    final model = vm.Matrix4.copy(parent)..multiply(transform);
    _modelMatrix.setFrom(model);
    return model;
  }

  bool somethingToDraw() => this is MeshNode;

  @override
  String toString() => "$runtimeType[$name]";
}

/// A transform and child links, with no drawable resources.
class GroupNode extends Node {
  GroupNode(super.name, [Node? child]) : super._() {
    if (child != null) children.add(child);
  }
}

/// A drawable node with required, borrowed GPU mesh and material.
///
/// Removing this node or replacing a resource does not dispose that resource.
/// Mesh nodes may also have children, drawn after the node itself.
class MeshNode extends Node {
  MeshNode(super.name, this.mesh, this.material) : super._();

  GpuMesh mesh;
  Material material;

  @Deprecated('Use mesh instead.')
  GpuMesh get meshData => mesh;

  @Deprecated('Use mesh instead.')
  set meshData(GpuMesh value) {
    mesh = value;
  }
}
