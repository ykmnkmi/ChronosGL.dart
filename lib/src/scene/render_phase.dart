part of 'lib.dart';

///  represents a simple scene graph.
///  Each scene is rendered by multiple invocation of a single RenderProgram
///  and contains additional UniformGroups to be passed to
///  that program at draw time.
class Scene extends NamedEntity {
  /// Scene initializes a scene
  ///
  /// @param name
  /// @param this.program
  /// @param unis
  Scene(super.name, this.program, [List<UniformGroup>? unis])
    : uniforms = unis ?? <UniformGroup>[];

  final RenderProgram program;
  final List<UniformGroup> uniforms;
  final List<Node> nodes = [];

  void add(Node node) {
    nodes.add(node);
  }

  void addAll(List<Node> nodes) {
    for (Node node in nodes) {
      add(node);
    }
  }

  void remove(Node n) {
    nodes.remove(n);
  }

  void removeAll() {
    nodes.clear();
  }
}

/// Draws a subtree using the last uniform group as a template for transforms.
/// The input list and its groups are borrowed; per-node transforms and material
/// are assembled in a separate list, including when drawing throws.
void drawRecursively(
  RenderProgram prog,
  Node node,
  vm.Matrix4 parent,
  List<DrawStats>? stats,
  List<UniformGroup> uniforms,
) {
  if (!node.enabled) return;
  // m is read-only!
  final vm.Matrix4 m = node.updateModelMatrix(parent);
  if (node.somethingToDraw()) {
    logDebug("drawing: $node");
    final transforms = UniformGroup(uniforms.last.name)
      ..getUniforms().addAll(uniforms.last.getUniforms());
    node.updateTransforms(transforms);
    prog.draw(node.meshData, [
      ...uniforms.take(uniforms.length - 1),
      transforms,
      node.material,
    ], stats);
  }
  for (Node child in node.children) {
    drawRecursively(prog, child, m, stats, uniforms);
  }
}

/// represents a sequence of Scenes.
class RenderPhase extends NamedEntity {
  RenderPhase(super.name, ChronosGL cgl, [Framebuffer? framebuffer])
    : _framebuffer = framebuffer ?? Framebuffer.screen(cgl);

  late final Framebuffer _framebuffer;
  final List<Scene> _scenes = <Scene>[];
  int _clearMode = glClearAll;

  int viewPortX = 0;
  int viewPortY = 0;
  int viewPortW = 0;
  int viewPortH = 0;

  Framebuffer get framebuffer => _framebuffer;

  set clearColorBuffer(bool clear) {
    if (clear) {
      _clearMode |= glColorBufferBit;
    } else {
      _clearMode &= ~glColorBufferBit;
    }
  }

  set clearDepthBuffer(bool clear) {
    if (clear) {
      _clearMode |= glDepthBufferBit;
    } else {
      _clearMode &= ~glDepthBufferBit;
    }
  }

  set clearStencilBuffer(bool clear) {
    if (clear) {
      _clearMode |= glStencilBufferBit;
    } else {
      _clearMode &= ~glStencilBufferBit;
    }
  }

  void add(Scene s) {
    _scenes.add(s);
  }

  // Draw all scenes in order of registration
  void draw([List<DrawStats>? stats]) {
    _framebuffer.activate(
      _clearMode,
      viewPortX,
      viewPortY,
      viewPortW,
      viewPortH,
    );

    for (Scene scene in _scenes) {
      if (!scene.enabled) continue;
      if (!scene.program.enabled) continue;

      final uniforms = <UniformGroup>[
        ...scene.uniforms,
        UniformGroup("transforms"),
      ];
      final vm.Matrix4 modelMatrix = vm.Matrix4.identity();
      for (Node node in scene.nodes) {
        drawRecursively(scene.program, node, modelMatrix, stats, uniforms);
      }
    }
  }
}
