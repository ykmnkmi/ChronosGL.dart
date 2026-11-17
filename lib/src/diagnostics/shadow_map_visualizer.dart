import '../core/lib.dart';
import '../scene/lib.dart';
import '../shader/lib.dart';
import '../shadows/shadow_map.dart';

final ShaderObject visualizeShadowmapVertexShaderLinearDepth16 =
    ShaderObject('shadowDebugV')
      ..addAttributeVars([aPosition, aTexUV])
      ..addVaryingVars([vTexUV])
      ..setBody([nullVertexShaderWithTextureForwardString]);

final ShaderObject visualizeShadowmapFragmentShaderLinearDepth16 =
    ShaderObject('shadowDebugF')
      ..addVaryingVars([vTexUV])
      ..addUniformVars([uTexture, uCameraNear, uCameraFar])
      ..setBodyWithMain([
        'float d = texture($uTexture, $vTexUV).x;',
        'float near = $uCameraNear;',
        'float far = $uCameraFar;',
        'float gray = (2.0 * near) / (far + near - d * (far - near));',
        '$oFragColor = vec4(vec3(gray), 1.0);',
      ]);

/// Optional depth visualization, borrowing [shadowMap] and owning debug assets.
///
/// The program, fullscreen mesh, and sampler are created on the first [draw].
/// A separate sampler disables comparison only for this draw; the depth texture
/// remains suitable for shadow sampling. Dispose before disposing [shadowMap].
class ShadowMapVisualizer {
  ShadowMapVisualizer(this.shadowMap)
    : _width = shadowMap.width,
      _height = shadowMap.height;

  final ShadowMap shadowMap;
  FullscreenPass? _fullscreen;
  GlSampler? _sampler;
  int _x = 0;
  int _y = 0;
  int _width;
  int _height;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  bool get isInitialized => _fullscreen != null;

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('ShadowMapVisualizer has been disposed');
  }

  void setViewport(int x, int y, int width, int height) {
    _checkNotDisposed();
    if (width < 0 || height < 0) {
      throw ArgumentError('Viewport width and height must be nonnegative');
    }
    _x = x;
    _y = y;
    _width = width;
    _height = height;
  }

  void _initialize(Texture texture) {
    final cgl = shadowMap.context;
    RenderProgram? program;
    FullscreenPass? fullscreen;
    GlSampler? sampler;
    try {
      program = RenderProgram(
        'shadowVisualize',
        cgl,
        visualizeShadowmapVertexShaderLinearDepth16,
        visualizeShadowmapFragmentShaderLinearDepth16,
      );
      fullscreen = FullscreenPass(
        program,
        name: 'shadowVisualize',
        ownsProgram: true,
      );
      fullscreen.material
        ..setUniform(uTexture, texture)
        ..setUniform(uCameraNear, shadowMap.near)
        ..setUniform(uCameraFar, shadowMap.far);
      sampler = cgl.createSampler();
      cgl.samplerParameteri(sampler, glTextureCompareMode, glNone);
      cgl.samplerParameteri(sampler, glTextureMinFilter, glNearest);
      cgl.samplerParameteri(sampler, glTextureMagFilter, glNearest);
      cgl.samplerParameteri(sampler, glTextureWrapS, glClampToEdge);
      cgl.samplerParameteri(sampler, glTextureWrapT, glClampToEdge);
      _fullscreen = fullscreen;
      _sampler = sampler;
    } catch (_) {
      for (final cleanup in <void Function()>[
        if (sampler != null) () => cgl.deleteSampler(sampler!),
        if (fullscreen != null) fullscreen.dispose,
        if (program != null) program.dispose,
      ]) {
        try {
          cleanup();
        } catch (_) {
          // Preserve the original failure and attempt all remaining cleanup.
        }
      }
      rethrow;
    }
  }

  /// Draws over the selected screen viewport without clearing prior output.
  ///
  /// Restores texture unit zero's 2D binding, sampler binding, and the active
  /// texture unit, including if drawing throws. Other render state follows the
  /// same convention as a normal fullscreen pass.
  void draw() {
    _checkNotDisposed();
    final texture = shadowMap.getMapTexture();
    if (_width == 0 || _height == 0) return;
    if (!isInitialized) _initialize(texture);
    final cgl = shadowMap.context;
    final previousUnit = cgl.getParameter(glActiveTexture) as int;
    cgl.activeTexture(glTexture0);
    final previousTexture = cgl.getParameter(glTextureBinding2D) as GlTexture?;
    final previousSampler = cgl.getParameter(glSamplerBinding) as GlSampler?;
    try {
      cgl.bindFramebuffer(glFramebuffer, null);
      cgl.viewport(_x, _y, _width, _height);
      cgl.bindSampler(0, _sampler);
      _fullscreen!.draw();
    } finally {
      try {
        cgl.bindSampler(0, previousSampler);
      } finally {
        try {
          cgl.bindTexture(glTexture2D, previousTexture);
        } finally {
          cgl.activeTexture(previousUnit);
        }
      }
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    Object? error;
    StackTrace? stack;
    for (final cleanup in <void Function()>[
      if (_sampler != null) () => shadowMap.context.deleteSampler(_sampler!),
      if (_fullscreen != null) _fullscreen!.dispose,
    ]) {
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
