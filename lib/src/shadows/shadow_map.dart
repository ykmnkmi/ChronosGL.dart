import 'package:vector_math/vector_math.dart' as vm;

import '../core/lib.dart';
import '../scene/lib.dart';

/// GLSL support for sampling comparison-enabled shadow maps.
const String shadowMapShaderLib = """
float GetShadow(vec3 depth, sampler2DShadow shadowMap, float bias1, float bias2) {
    depth.z = depth.z - bias1;
    return texture(shadowMap, depth);
}
""";

final ShaderObject shadowVertexShaderDepth = ShaderObject('ShadowMapV')
  ..addAttributeVars([aPosition])
  ..addUniformVars([uLightPerspectiveViewMatrix, uModelMatrix])
  ..setBodyWithMain([
    'gl_Position = $uLightPerspectiveViewMatrix * $uModelMatrix * vec4($aPosition, 1.0);',
  ]);

final ShaderObject shadowFragmentShaderDepth = ShaderObject('ShadowMapF')
  ..setBodyWithMain(['$oFragColor = vec4(1.0);']);

/// Owns the framebuffer, its attachments, and the shadow generation program.
///
/// Casters are borrowed. Construction creates no debug geometry, program or
/// sampler; use `ShadowMapVisualizer` from `debug.dart` to inspect the depth map.
/// Call [dispose] after borrowers have finished using [getMapTexture].
class ShadowMap {
  ShadowMap(
    this.context,
    this.width,
    this.height,
    this.near,
    this.far, {
    int format = glDepthComponent24,
  }) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Shadow map width and height must be positive');
    }
    if (!near.isFinite || !far.isFinite || near <= 0 || far <= near) {
      throw ArgumentError('Shadow map requires finite 0 < near < far');
    }
    Texture? color;
    Texture? depth;
    Framebuffer? framebuffer;
    RenderProgram? program;
    final previousTexture =
        context.getParameter(glTextureBinding2D) as GlTexture?;
    final previousDraw =
        context.getParameter(glDrawFramebufferBinding) as GlFramebuffer?;
    final previousRead =
        context.getParameter(glReadFramebufferBinding) as GlFramebuffer?;
    try {
      color = TypedTexture(
        context,
        'shadow::color',
        width,
        height,
        glRgba8,
        texturePropertiesFramebuffer,
      );
      depth = TypedTexture(
        context,
        'shadow::depth',
        width,
        height,
        format,
        texturePropertiesShadowMap,
      );
      framebuffer = Framebuffer.withAttachments(
        context,
        colorTexture: color,
        depthTexture: depth,
        takeOwnership: [color, depth],
      );
      program = RenderProgram(
        'shadowCompute',
        context,
        shadowVertexShaderDepth,
        shadowFragmentShaderDepth,
      );
      _depthTexture = depth;
      _shadowBuffer = framebuffer;
      _program = program;
      _batch = RenderBatch('shadowCompute', program, [_uniforms]);
      _pass = RenderPass('compute-shadow', context, framebuffer)
        ..viewPortW = width
        ..viewPortH = height
        ..clearColorBuffer = false
        ..clearStencilBuffer = false
        ..add(_batch);
    } catch (_) {
      for (final cleanup in <void Function()>[
        if (program != null) program.dispose,
        if (framebuffer != null) framebuffer.dispose,
        if (depth != null) depth.dispose,
        if (color != null) color.dispose,
        () => context.bindTexture(glTexture2D, previousTexture),
        () => context.bindFramebuffer(glDrawFramebuffer, previousDraw),
        () => context.bindFramebuffer(glReadFramebuffer, previousRead),
      ]) {
        try {
          cleanup();
        } catch (_) {
          // Preserve the original creation failure while attempting all cleanup.
        }
      }
      rethrow;
    }
  }

  final ChronosGL context;
  final int width;
  final int height;

  /// Clipping distances used to linearize depth during optional visualization.
  final double near;
  final double far;
  final UniformGroup _uniforms = UniformGroup('shadow uniforms');
  late final Texture _depthTexture;
  late final Framebuffer _shadowBuffer;
  late final RenderProgram _program;
  late final RenderBatch _batch;
  late final RenderPass _pass;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('ShadowMap has been disposed');
  }

  void addShadowCaster(Node node) {
    _checkNotDisposed();
    _batch.add(node);
  }

  void clearShadowCasters() {
    _checkNotDisposed();
    _batch.removeAll();
  }

  void compute(vm.Matrix4 lightMatrix) {
    _checkNotDisposed();
    _uniforms.forceUniform(uLightPerspectiveViewMatrix, lightMatrix);
    // Depth clears respect the current write mask, including the false mask
    // left by an earlier fullscreen visualization.
    context.depthMask(true);
    _pass.draw();
  }

  /// Returns an independent vector; changing it does not resize the map.
  vm.Vector2 getMapSize() => vm.Vector2(width.toDouble(), height.toDouble());

  Texture getMapTexture() {
    _checkNotDisposed();
    return _depthTexture;
  }

  /// Releases owned resources once. Borrowed casters and their resources live on.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _batch.removeAll();
    _pass.removeAll();
    _uniforms.getUniforms().clear();
    Object? error;
    StackTrace? stack;
    for (final cleanup in [_program.dispose, _shadowBuffer.dispose]) {
      try {
        cleanup();
      } catch (failure, trace) {
        error ??= failure;
        stack ??= trace;
      }
    }
    if (error != null) Error.throwWithStackTrace(error, stack!);
  }
}
