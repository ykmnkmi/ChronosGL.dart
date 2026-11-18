/// Scene containers, drawables, ordered batches, and render passes.
///
/// Nodes borrow meshes and materials. Removing a node does not dispose resources.
/// Pass viewport coordinates and dimensions are framebuffer pixels.
library;

export 'src/scene/lib.dart'
    show Node, GroupNode, MeshNode, RenderBatch, RenderPass, Scene, RenderPhase;
