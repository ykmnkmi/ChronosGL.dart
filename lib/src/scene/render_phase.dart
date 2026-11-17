part of 'lib.dart';

/// Ordered scene roots drawn by one [program].
///
/// The supplied list of uniforms is copied; its groups, the program and nodes
/// remain borrowed. Editing links does not dispose their GPU resources.
class RenderBatch extends NamedEntity {
  RenderBatch(super.name, this.program, [List<UniformGroup>? uniforms])
    : uniforms = List<UniformGroup>.of(uniforms ?? const []);

  final RenderProgram program;
  final List<UniformGroup> uniforms;
  final List<Node> nodes = [];

  void add(Node node) {
    nodes.add(node);
  }

  void addAll(List<Node> nodes) {
    this.nodes.addAll(nodes);
  }

  void remove(Node node) {
    nodes.remove(node);
  }

  void removeAll() {
    nodes.clear();
  }
}

@Deprecated('Use RenderBatch instead.')
typedef Scene = RenderBatch;

/// Draws a subtree in depth-first, parent-before-child insertion order.
///
/// The last uniform group, when present, is a template for per-node transforms.
/// Input lists, groups and matrices are borrowed and unchanged, even on errors.
/// Shared nodes are visited for each path; a cycle on the current path throws
/// [StateError]. No traversal state survives an invocation or a failed draw.
void drawRecursively(
  RenderProgram prog,
  Node node,
  vm.Matrix4 parent,
  List<DrawStats>? stats,
  List<UniformGroup> uniforms,
) {
  _drawNode(prog, node, parent, stats, uniforms, Set<Node>.identity());
}

void _drawNode(
  RenderProgram program,
  Node node,
  vm.Matrix4 parent,
  List<DrawStats>? stats,
  List<UniformGroup> uniforms,
  Set<Node> path,
) {
  if (!node.enabled) return;
  if (!path.add(node)) {
    throw StateError('Scene graph cycle at node ${node.name}');
  }
  try {
    final model = node.updateModelMatrix(parent);
    if (node is MeshNode) {
      final template = uniforms.isEmpty ? null : uniforms.last;
      final transforms = UniformGroup(template?.name ?? 'transforms');
      if (template != null) {
        transforms.getUniforms().addAll(template.getUniforms());
      }
      node.updateTransforms(transforms, model);
      program.draw(node.mesh, [
        if (uniforms.isNotEmpty) ...uniforms.take(uniforms.length - 1),
        transforms,
        node.material,
      ], stats);
    }
    for (final child in node.children) {
      _drawNode(program, child, model, stats, uniforms, path);
    }
  } finally {
    path.remove(node);
  }
}

/// An ordered sequence of batches targeting one framebuffer and viewport.
///
/// Each enabled pass with a nonempty viewport activates and clears its
/// framebuffer exactly once, before any batch is drawn. Clear flags select the
/// buffers to clear; disable them to preserve earlier pass output. Invoke passes
/// in the desired order. Batches, programs, nodes and externally supplied
/// framebuffers are borrowed. A disabled pass or empty viewport performs no
/// framebuffer work.
class RenderPass extends NamedEntity {
  RenderPass(super.name, ChronosGL cgl, [Framebuffer? framebuffer])
    : _framebuffer = framebuffer ?? Framebuffer.screen(cgl);

  final Framebuffer _framebuffer;
  final List<RenderBatch> _batches = [];
  int _clearMode = glClearAll;

  int viewPortX = 0;
  int viewPortY = 0;
  int viewPortW = 0;
  int viewPortH = 0;

  Framebuffer get framebuffer => _framebuffer;

  /// A snapshot of the registered batch links, in draw order.
  List<RenderBatch> get batches => List<RenderBatch>.unmodifiable(_batches);

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

  void add(RenderBatch batch) {
    _batches.add(batch);
  }

  void remove(RenderBatch batch) {
    _batches.remove(batch);
  }

  void removeAll() {
    _batches.clear();
  }

  void draw([List<DrawStats>? stats]) {
    if (!enabled) return;
    if (viewPortW < 0 || viewPortH < 0) {
      throw ArgumentError('Viewport width and height must be nonnegative');
    }
    if (viewPortW == 0 || viewPortH == 0) return;
    _framebuffer.activate(
      _clearMode,
      viewPortX,
      viewPortY,
      viewPortW,
      viewPortH,
    );

    for (final batch in _batches) {
      if (!batch.enabled || !batch.program.enabled) continue;
      final uniforms = <UniformGroup>[
        ...batch.uniforms,
        UniformGroup('transforms'),
      ];
      for (final node in batch.nodes) {
        drawRecursively(
          batch.program,
          node,
          vm.Matrix4.identity(),
          stats,
          uniforms,
        );
      }
    }
  }
}

@Deprecated('Use RenderPass instead.')
typedef RenderPhase = RenderPass;
